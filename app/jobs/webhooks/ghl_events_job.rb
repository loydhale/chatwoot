# frozen_string_literal: true

class Webhooks::GhlEventsJob < ApplicationJob
  queue_as :default

  def perform(event_type, params = {})
    location_id = extract_location_id(params)
    hook = find_hook(location_id)

    unless hook
      Rails.logger.warn("GHL webhook: no integration found for location '#{location_id}'")
      return
    end

    case event_type
    when 'contact.create'
      Ghl::ContactSyncService.new(account: hook.account, hook: hook).create_from_ghl(params)
    when 'contact.update'
      Ghl::ContactSyncService.new(account: hook.account, hook: hook).update_from_ghl(params)
    when 'contact.delete'
      Ghl::ContactSyncService.new(account: hook.account, hook: hook).delete_from_ghl(params)
    when 'conversation.message'
      Ghl::MessageSyncService.new(account: hook.account, hook: hook).process_message(params) if defined?(Ghl::MessageSyncService)
    end
  rescue StandardError => e
    Rails.logger.error("GHL webhook processing failed [#{event_type}]: #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    raise # re-raise so Sidekiq can retry
  end

  private

  def extract_location_id(params)
    params['locationId'] || params['location_id'] ||
      params.dig('contact', 'locationId') ||
      params.dig('data', 'locationId')
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
