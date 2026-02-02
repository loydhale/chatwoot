# frozen_string_literal: true

class Webhooks::GhlEventsJob < ApplicationJob
  queue_as :default

  def perform(event_type, params = {})
    Rails.logger.info("GHL events job: processing #{event_type}")

    case event_type
    # --- App lifecycle (may not have a hook yet) ---
    when 'app.installed'
      handle_app_installed(params)
      return
    when 'app.uninstalled'
      handle_app_uninstalled(params)
      return
    end

    # --- All other events require an active hook ---
    location_id = extract_location_id(params)
    hook = find_hook(location_id)

    unless hook
      Rails.logger.warn("GHL webhook: no integration found for location '#{location_id}'")
      return
    end

    account = hook.account

    case event_type
    # --- Contact Events ---
    when 'contact.create'
      Ghl::ContactSyncService.new(account: account, hook: hook).create_from_ghl(params)
    when 'contact.update'
      Ghl::ContactSyncService.new(account: account, hook: hook).update_from_ghl(params)
    when 'contact.delete'
      Ghl::ContactSyncService.new(account: account, hook: hook).delete_from_ghl(params)

    # --- Message Events ---
    when 'conversation.message'
      Ghl::MessageSyncService.new(account: account, hook: hook).process_message(params)

    # --- Conversation Status ---
    when 'conversation.status'
      Ghl::MessageSyncService.new(account: account, hook: hook).sync_conversation_status(params)

    # --- Opportunity Events ---
    when 'opportunity.create'
      Ghl::OpportunitySyncService.new(account: account, hook: hook).create_from_ghl(params)
    when 'opportunity.update'
      Ghl::OpportunitySyncService.new(account: account, hook: hook).update_from_ghl(params)
    when 'opportunity.delete'
      Ghl::OpportunitySyncService.new(account: account, hook: hook).delete_from_ghl(params)
    when 'opportunity.status_change'
      Ghl::OpportunitySyncService.new(account: account, hook: hook).status_change_from_ghl(params)

    # --- Location Events (multi-tenant) ---
    when 'location.create'
      handle_location_create(account, params)
    when 'location.update'
      handle_location_update(account, params)
    end
  rescue StandardError => e
    Rails.logger.error("GHL webhook processing failed [#{event_type}]: #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    raise # re-raise so Sidekiq can retry
  end

  private

  # --- App Lifecycle ---

  def handle_app_installed(params)
    location_id = extract_location_id(params)
    company_id = params['companyId'] || params.dig('data', 'companyId')

    Rails.logger.info("GHL app installed: location=#{location_id} company=#{company_id}")

    # Check if workspace already exists (OAuth callback usually creates it)
    existing = Account.find_by(ghl_location_id: location_id) if location_id.present?
    existing ||= Account.find_by(ghl_company_id: company_id) if company_id.present?

    if existing
      Rails.logger.info("GHL app installed: workspace already exists (account=#{existing.id})")
      # Reactivate if suspended
      sub = existing.ghl_subscription
      sub&.activate! if sub&.status.in?(%w[cancelled suspended])
    else
      # Provision will happen when OAuth callback fires — just log for now
      Rails.logger.info("GHL app installed: awaiting OAuth callback for provisioning")
    end
  end

  def handle_app_uninstalled(params)
    location_id = extract_location_id(params)
    company_id = params['companyId'] || params.dig('data', 'companyId')

    Rails.logger.info("GHL app uninstalled: location=#{location_id} company=#{company_id}")

    hook = find_hook(location_id)
    return unless hook

    account = hook.account

    # Disable the hook (don't delete — they might reinstall)
    hook.update!(status: 'disabled')

    # Suspend the subscription
    sub = account.ghl_subscription
    sub&.suspend!

    Rails.logger.info("GHL app uninstalled: disabled hook and suspended subscription for account=#{account.id}")
  end

  # --- Location Events ---

  def handle_location_create(account, params)
    sub = account.ghl_subscription
    return unless sub

    new_count = sub.locations_count + 1
    if new_count > sub.locations_limit
      Rails.logger.warn(
        "GHL location create: account #{account.id} exceeds location limit " \
        "(#{new_count}/#{sub.locations_limit}) — upgrade required"
      )
    end

    sub.update!(
      locations_count: new_count,
      usage_data: sub.usage_data.merge(
        'last_location_added' => Time.current.iso8601,
        'location_ids' => ((sub.usage_data['location_ids'] || []) + [extract_location_id(params)]).uniq
      )
    )
  end

  def handle_location_update(account, params)
    # Just log location updates for now — useful for tracking name changes, etc.
    location_data = params['location'] || params['data'] || {}
    Rails.logger.info(
      "GHL location update: account=#{account.id} location=#{location_data['id']} name=#{location_data['name']}"
    )
  end

  # --- Helpers ---

  def extract_location_id(params)
    params['locationId'] || params['location_id'] ||
      params.dig('contact', 'locationId') ||
      params.dig('data', 'locationId') ||
      params.dig('location', 'id')
  end

  def find_hook(location_id)
    return nil if location_id.blank?

    Integrations::Hook.find_by(
      app_id: 'gohighlevel',
      status: 'enabled',
      reference_id: location_id
    )
  end
end
