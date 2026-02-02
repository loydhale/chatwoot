# frozen_string_literal: true

# Syncs GHL opportunities to DeskFlows conversations with pipeline metadata.
#
# GHL opportunities map to DeskFlows conversations with:
#   - Labels derived from pipeline stage names
#   - Custom attributes tracking monetary value, pipeline, and stage
#   - Notes attached as private messages when stage changes
#
# Supported events:
#   - opportunity.create  → create conversation with pipeline context
#   - opportunity.update  → update labels/attributes, add stage-change note
#   - opportunity.delete  → resolve conversation, mark as deleted
#   - opportunity.status_change → update conversation status
#
class Ghl::OpportunitySyncService
  attr_reader :account, :hook

  def initialize(account:, hook:)
    @account = account
    @hook = hook
  end

  # --- Inbound: GHL → DeskFlows ---

  def create_from_ghl(params)
    data = extract_opportunity_data(params)
    return if data['id'].blank?

    # Idempotency: don't create duplicates
    existing = find_conversation_by_opportunity_id(data['id'])
    return update_from_ghl(params) if existing

    contact = resolve_contact(data)
    return unless contact

    inbox = default_inbox
    return unless inbox

    contact_inbox = ContactInbox.find_or_create_by!(
      contact: contact,
      inbox: inbox,
      source_id: "ghl_opp:#{data['id']}"
    )

    conversation = account.conversations.create!(
      contact: contact,
      inbox: inbox,
      contact_inbox: contact_inbox,
      status: map_opportunity_status(data['status']),
      identifier: "ghl_opp:#{data['id']}",
      custom_attributes: build_custom_attributes(data),
      additional_attributes: build_additional_attributes(data)
    )

    # Apply pipeline/stage as labels
    apply_labels(conversation, data)

    # Add initial note with opportunity details
    add_opportunity_note(conversation, data, 'created')

    Rails.logger.info(
      "GHL opportunity sync: created conversation #{conversation.id} " \
      "from opportunity #{data['id']} (pipeline: #{data['pipelineName']}, stage: #{data['stageName']})"
    )

    conversation
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("GHL opportunity sync: failed to create conversation: #{e.message}")
    nil
  end

  def update_from_ghl(params)
    data = extract_opportunity_data(params)
    return if data['id'].blank?

    conversation = find_conversation_by_opportunity_id(data['id'])
    unless conversation
      Rails.logger.info("GHL opportunity sync: conversation not found for opportunity #{data['id']}, creating")
      return create_from_ghl(params)
    end

    old_attrs = conversation.custom_attributes || {}
    old_stage = old_attrs['ghl_opportunity_stage']

    # Update conversation attributes
    conversation.update!(
      custom_attributes: (old_attrs).merge(build_custom_attributes(data)),
      additional_attributes: (conversation.additional_attributes || {}).merge(build_additional_attributes(data)),
      status: map_opportunity_status(data['status'])
    )

    # Re-apply labels if pipeline/stage changed
    apply_labels(conversation, data)

    # Add stage-change note if stage actually changed
    new_stage = data['stageName'] || data['stageId']
    if old_stage.present? && new_stage.present? && old_stage != new_stage
      add_opportunity_note(conversation, data, 'stage_changed', old_stage: old_stage)
    end

    Rails.logger.info("GHL opportunity sync: updated conversation #{conversation.id} from opportunity #{data['id']}")
    conversation
  end

  def delete_from_ghl(params)
    data = extract_opportunity_data(params)
    return if data['id'].blank?

    conversation = find_conversation_by_opportunity_id(data['id'])
    unless conversation
      Rails.logger.info("GHL opportunity sync: cannot delete — conversation not found for opportunity #{data['id']}")
      return
    end

    # Add a note about deletion, then resolve
    add_opportunity_note(conversation, data, 'deleted')
    conversation.update!(status: :resolved)

    Rails.logger.info("GHL opportunity sync: resolved conversation #{conversation.id} (opportunity #{data['id']} deleted)")
    conversation
  end

  def status_change_from_ghl(params)
    data = extract_opportunity_data(params)
    return if data['id'].blank?

    conversation = find_conversation_by_opportunity_id(data['id'])
    return unless conversation

    new_status = map_opportunity_status(data['status'])
    return if new_status.nil?

    old_status = conversation.status
    conversation.update!(status: new_status)

    add_opportunity_note(conversation, data, 'status_changed', old_status: old_status)

    Rails.logger.info(
      "GHL opportunity sync: status changed #{old_status} → #{new_status} " \
      "for conversation #{conversation.id} (opportunity #{data['id']})"
    )
    conversation
  end

  private

  # --- Data Extraction ---

  def extract_opportunity_data(params)
    data = params['opportunity'] || params['data'] || params

    # Normalize field names across GHL webhook formats
    {
      'id' => data['id'] || data['opportunityId'],
      'name' => data['name'] || data['opportunityName'],
      'status' => data['status'],
      'monetaryValue' => data['monetaryValue'] || data['monetary_value'],
      'pipelineId' => data['pipelineId'] || data['pipeline_id'],
      'pipelineName' => data['pipelineName'] || data['pipeline_name'],
      'stageId' => data['pipelineStageId'] || data['stageId'] || data['stage_id'],
      'stageName' => data['stageName'] || data['stage_name'],
      'contactId' => data['contactId'] || data['contact_id'] || params.dig('contact', 'id'),
      'locationId' => data['locationId'] || params['locationId'],
      'assignedTo' => data['assignedTo'] || data['assigned_to'],
      'source' => data['source'],
      'dateAdded' => data['dateAdded'] || data['createdAt'],
      'lastStatusChangeAt' => data['lastStatusChangeAt'] || data['updatedAt']
    }
  end

  # --- Contact Resolution ---

  def resolve_contact(data)
    ghl_contact_id = data['contactId']
    return nil if ghl_contact_id.blank?

    # Try to find existing contact linked to GHL
    contact = account.contacts.find_by(identifier: "ghl:#{ghl_contact_id}")
    contact ||= account.contacts.where("custom_attributes->>'ghl_contact_id' = ?", ghl_contact_id).first

    contact ||= account.contacts.create!(
      identifier: "ghl:#{ghl_contact_id}",
      name: data['name'].presence || 'Opportunity Contact',
      custom_attributes: {
        'ghl_contact_id' => ghl_contact_id,
        'ghl_location_id' => data['locationId'],
        'ghl_pending_enrichment' => true
      }
    )

    contact
  end

  # --- Conversation Lookup ---

  def find_conversation_by_opportunity_id(opportunity_id)
    return nil if opportunity_id.blank?

    account.conversations.find_by(identifier: "ghl_opp:#{opportunity_id}") ||
      account.conversations.where("custom_attributes->>'ghl_opportunity_id' = ?", opportunity_id).first
  end

  # --- Attribute Building ---

  def build_custom_attributes(data)
    {
      'ghl_opportunity_id' => data['id'],
      'ghl_opportunity_name' => data['name'],
      'ghl_opportunity_status' => data['status'],
      'ghl_opportunity_value' => data['monetaryValue'],
      'ghl_opportunity_pipeline' => data['pipelineName'] || data['pipelineId'],
      'ghl_opportunity_stage' => data['stageName'] || data['stageId'],
      'ghl_opportunity_source' => data['source'],
      'ghl_opportunity_synced_at' => Time.current.iso8601
    }.compact_blank
  end

  def build_additional_attributes(data)
    {
      'ghl_pipeline_id' => data['pipelineId'],
      'ghl_stage_id' => data['stageId'],
      'ghl_assigned_to' => data['assignedTo'],
      'ghl_opportunity_created_at' => data['dateAdded']
    }.compact_blank
  end

  # --- Labels ---

  def apply_labels(conversation, data)
    labels = []
    labels << "pipeline:#{sanitize_label(data['pipelineName'])}" if data['pipelineName'].present?
    labels << "stage:#{sanitize_label(data['stageName'])}" if data['stageName'].present?
    labels << 'ghl-opportunity'

    # Merge with existing labels (don't overwrite non-GHL labels)
    existing = conversation.label_list || []
    non_ghl_labels = existing.reject { |l| l.start_with?('pipeline:', 'stage:') || l == 'ghl-opportunity' }
    conversation.update!(cached_label_list: (non_ghl_labels + labels).uniq.join(','))
  end

  def sanitize_label(name)
    return '' if name.blank?

    name.downcase.gsub(/[^a-z0-9\-_]/, '-').squeeze('-').truncate(50, omission: '')
  end

  # --- Notes ---

  def add_opportunity_note(conversation, data, event, old_stage: nil, old_status: nil)
    content = build_note_content(data, event, old_stage: old_stage, old_status: old_status)

    conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      message_type: :activity,
      content: content,
      content_type: :text,
      private: true,
      additional_attributes: {
        'ghl_opportunity_event' => event,
        'ghl_opportunity_id' => data['id'],
        'ghl_synced_at' => Time.current.iso8601
      }
    )
  end

  def build_note_content(data, event, old_stage: nil, old_status: nil)
    case event
    when 'created'
      parts = ["🎯 GHL Opportunity created: **#{data['name'] || 'Untitled'}**"]
      parts << "Pipeline: #{data['pipelineName']}" if data['pipelineName'].present?
      parts << "Stage: #{data['stageName']}" if data['stageName'].present?
      parts << "Value: $#{data['monetaryValue']}" if data['monetaryValue'].present?
      parts.join("\n")
    when 'stage_changed'
      "📋 GHL Opportunity stage changed: #{old_stage} → #{data['stageName'] || data['stageId']}"
    when 'status_changed'
      "🔄 GHL Opportunity status changed: #{old_status} → #{data['status']}"
    when 'deleted'
      "🗑️ GHL Opportunity deleted: #{data['name'] || data['id']}"
    else
      "GHL Opportunity event: #{event}"
    end
  end

  # --- Status Mapping ---

  def map_opportunity_status(ghl_status)
    case ghl_status.to_s.downcase
    when 'open', 'active', '' then :open
    when 'won', 'completed' then :resolved
    when 'lost', 'abandoned' then :resolved
    when 'pending' then :pending
    end
  end

  # --- Inbox ---

  def default_inbox
    account.inboxes.find_by(name: 'GHL Messages') ||
      account.inboxes.joins(
        "INNER JOIN channel_api ON channel_api.id = inboxes.channel_id AND inboxes.channel_type = 'Channel::Api'"
      ).first ||
      account.inboxes.first
  end
end
