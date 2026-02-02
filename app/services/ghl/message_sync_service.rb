# frozen_string_literal: true

# Syncs messages and conversations between GHL and DeskFlows.
#
# Handles:
#   - Inbound messages from GHL → create/append to DeskFlows conversation
#   - Outbound messages from DeskFlows → send via GHL API
#   - Conversation status sync (open, closed, snoozed)
#
class Ghl::MessageSyncService
  GHL_API_BASE = 'https://services.leadconnectorhq.com'

  attr_reader :account, :hook

  def initialize(account:, hook:)
    @account = account
    @hook = hook
  end

  # --- Inbound: GHL → DeskFlows ---

  def process_message(params)
    data = extract_message_data(params)
    return if data['id'].blank?

    # Skip if we already have this message (idempotency)
    return if message_already_synced?(data['id'])

    contact = find_or_create_contact(data)
    return unless contact

    conversation = find_or_create_conversation(contact, data)
    return unless conversation

    message = create_message(conversation, contact, data)

    Rails.logger.info(
      "GHL message sync: created message #{message.id} in conversation #{conversation.id} " \
      "from GHL message #{data['id']}"
    )

    message
  rescue StandardError => e
    Rails.logger.error("GHL message sync failed: #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    raise
  end

  # --- Outbound: DeskFlows → GHL ---

  def send_message(conversation, message)
    contact = conversation.contact
    ghl_contact_id = extract_ghl_contact_id(contact)

    unless ghl_contact_id
      Rails.logger.warn("GHL message send: no GHL contact ID for contact #{contact.id}")
      return nil
    end

    channel_type = determine_channel_type(conversation, contact)
    payload = build_outbound_payload(ghl_contact_id, message, channel_type)

    response = ghl_api_request(:post, '/conversations/messages', payload)

    # Store GHL message ID for dedup
    if response['messageId'].present?
      message.update!(
        source_id: response['messageId'],
        additional_attributes: (message.additional_attributes || {}).merge(
          'ghl_message_id' => response['messageId'],
          'ghl_sent_at' => Time.current.iso8601
        )
      )
    end

    response
  rescue StandardError => e
    Rails.logger.error("GHL message send failed for message #{message.id}: #{e.message}")
    nil
  end

  # --- Conversation Status Sync ---

  def sync_conversation_status(params)
    data = params['conversation'] || params['data'] || params
    ghl_conversation_id = data['id'] || data['conversationId']
    return unless ghl_conversation_id

    conversation = find_conversation_by_ghl_id(ghl_conversation_id)
    return unless conversation

    new_status = map_ghl_status(data['status'])
    conversation.update!(status: new_status) if new_status && conversation.status != new_status

    Rails.logger.info("GHL conversation sync: updated #{conversation.id} status to #{new_status}")
  end

  private

  # --- Message Data Extraction ---

  def extract_message_data(params)
    # GHL sends message data in various shapes
    data = params['message'] || params['data'] || params

    # Normalize field names
    {
      'id' => data['id'] || data['messageId'],
      'body' => data['body'] || data['message'] || data['text'],
      'direction' => data['direction'] || data['type'] || classify_direction(params),
      'contactId' => data['contactId'] || params.dig('contact', 'id'),
      'conversationId' => data['conversationId'],
      'locationId' => data['locationId'] || params['locationId'],
      'dateAdded' => data['dateAdded'] || data['createdAt'],
      'attachments' => data['attachments'] || [],
      'contentType' => data['contentType'] || 'text',
      'source' => data['source'] || data['channel'] || 'ghl'
    }
  end

  def classify_direction(params)
    type = params['type'] || params['event']
    case type
    when 'InboundMessage', 'inbound'
      'inbound'
    when 'OutboundMessage', 'ConversationProviderOutboundMessage', 'outbound'
      'outbound'
    else
      'inbound'
    end
  end

  # --- Contact Resolution ---

  def find_or_create_contact(data)
    ghl_contact_id = data['contactId']
    return nil if ghl_contact_id.blank?

    # Try to find by GHL contact ID
    contact = account.contacts.find_by(identifier: "ghl:#{ghl_contact_id}")
    contact ||= account.contacts.where("custom_attributes->>'ghl_contact_id' = ?", ghl_contact_id).first

    unless contact
      # Create a placeholder contact — will be enriched by contact sync
      contact = account.contacts.create!(
        identifier: "ghl:#{ghl_contact_id}",
        name: "GHL Contact #{ghl_contact_id[0..7]}",
        custom_attributes: {
          'ghl_contact_id' => ghl_contact_id,
          'ghl_location_id' => data['locationId'],
          'ghl_pending_enrichment' => true
        }
      )

      # Queue enrichment from GHL API
      Ghl::ContactEnrichmentJob.perform_later(account.id, ghl_contact_id) if defined?(Ghl::ContactEnrichmentJob)
    end

    contact
  end

  # --- Conversation Resolution ---

  def find_or_create_conversation(contact, data)
    ghl_conversation_id = data['conversationId']

    # Try to find existing conversation by GHL ID
    conversation = find_conversation_by_ghl_id(ghl_conversation_id) if ghl_conversation_id.present?

    # Fall back to finding most recent open conversation for this contact
    conversation ||= account.conversations
                            .where(contact: contact, status: [:open, :pending])
                            .order(last_activity_at: :desc)
                            .first

    unless conversation
      inbox = default_inbox
      return nil unless inbox

      contact_inbox = ContactInbox.find_or_create_by!(
        contact: contact,
        inbox: inbox,
        source_id: "ghl:#{data['contactId']}"
      )

      conversation = account.conversations.create!(
        contact: contact,
        inbox: inbox,
        contact_inbox: contact_inbox,
        status: :open,
        identifier: ghl_conversation_id.present? ? "ghl:#{ghl_conversation_id}" : nil,
        additional_attributes: {
          'ghl_conversation_id' => ghl_conversation_id,
          'ghl_source' => data['source'],
          'ghl_synced_at' => Time.current.iso8601
        }
      )
    end

    conversation
  end

  def find_conversation_by_ghl_id(ghl_id)
    return nil if ghl_id.blank?

    account.conversations.find_by(identifier: "ghl:#{ghl_id}") ||
      account.conversations.where("additional_attributes->>'ghl_conversation_id' = ?", ghl_id).first
  end

  # --- Message Creation ---

  def create_message(conversation, contact, data)
    direction = data['direction']
    message_type = direction == 'outbound' ? :outgoing : :incoming

    message = conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      message_type: message_type,
      content: sanitize_content(data['body']),
      source_id: data['id'],
      sender: message_type == :incoming ? contact : nil,
      content_type: map_content_type(data['contentType']),
      additional_attributes: {
        'ghl_message_id' => data['id'],
        'ghl_conversation_id' => data['conversationId'],
        'ghl_source' => data['source'],
        'ghl_synced_at' => Time.current.iso8601
      }
    )

    # Handle attachments
    process_attachments(message, data['attachments']) if data['attachments'].present?

    # Track AI usage if this was an AI-generated response
    track_ai_usage(data) if data['source'] == 'hudley_ai'

    message
  end

  def sanitize_content(body)
    return '' if body.blank?

    # Strip HTML if present, preserve basic formatting
    ActionController::Base.helpers.strip_tags(body).strip
  end

  def map_content_type(ghl_type)
    case ghl_type
    when 'text', nil then :text
    when 'input_select' then :input_select
    when 'cards' then :cards
    else :text
    end
  end

  # --- Attachments ---

  def process_attachments(message, attachments)
    attachments.each do |att|
      url = att['url'] || att['payload']
      next if url.blank?

      message.attachments.create!(
        account: account,
        file_type: map_file_type(att['type'] || att['contentType']),
        external_url: url,
        data_attributes: {
          'ghl_attachment' => true,
          'original_type' => att['type']
        }
      )
    rescue StandardError => e
      Rails.logger.warn("GHL attachment sync failed: #{e.message}")
    end
  end

  def map_file_type(type)
    case type.to_s.downcase
    when /image/ then :image
    when /audio/ then :audio
    when /video/ then :video
    else :file
    end
  end

  # --- Dedup ---

  def message_already_synced?(ghl_message_id)
    return false if ghl_message_id.blank?

    account.messages.exists?(source_id: ghl_message_id)
  end

  # --- Outbound Helpers ---

  def extract_ghl_contact_id(contact)
    return contact.identifier.delete_prefix('ghl:') if contact.identifier&.start_with?('ghl:')

    contact.custom_attributes&.dig('ghl_contact_id')
  end

  def determine_channel_type(_conversation, contact)
    # Determine best channel based on contact info
    if contact.phone_number.present?
      'SMS'
    elsif contact.email.present?
      'Email'
    else
      'SMS' # default
    end
  end

  def build_outbound_payload(ghl_contact_id, message, channel_type)
    {
      type: channel_type,
      contactId: ghl_contact_id,
      message: message.content,
      locationId: hook.reference_id
    }
  end

  # --- Status Mapping ---

  def map_ghl_status(ghl_status)
    case ghl_status.to_s.downcase
    when 'open', 'active' then :open
    when 'closed', 'won', 'lost', 'completed' then :resolved
    when 'snoozed' then :snoozed
    end
  end

  # --- AI Usage Tracking ---

  def track_ai_usage(data)
    subscription = account.ghl_subscription
    return unless subscription

    credits = estimate_ai_credits(data['body'])
    subscription.increment_ai_usage!(credits)
  end

  def estimate_ai_credits(content)
    # ~1 credit per 100 tokens (rough estimate)
    return 1 if content.blank?

    word_count = content.split.size
    [(word_count / 75.0).ceil, 1].max
  end

  # --- Inbox ---

  def default_inbox
    # Find the GHL API inbox, or any API inbox, or the first inbox
    account.inboxes.find_by(name: 'GHL Messages') ||
      account.inboxes.joins("INNER JOIN channel_api ON channel_api.id = inboxes.channel_id AND inboxes.channel_type = 'Channel::Api'").first ||
      account.inboxes.first
  end

  # --- GHL API ---

  def ghl_api_request(method, path, body = nil)
    uri = URI("#{GHL_API_BASE}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = case method
              when :post
                req = Net::HTTP::Post.new(uri)
                req.body = body.to_json if body
                req
              when :get
                Net::HTTP::Get.new(uri)
              end

    request['Authorization'] = "Bearer #{hook.access_token}"
    request['Content-Type'] = 'application/json'
    request['Version'] = '2021-07-28'

    response = http.request(request)
    raise "GHL API #{method.upcase} #{path} failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
