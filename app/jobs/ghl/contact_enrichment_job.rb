# frozen_string_literal: true

# Enriches a placeholder contact with full data from the GHL API.
# Queued when a message arrives for a contact we haven't synced yet.
class Ghl::ContactEnrichmentJob < ApplicationJob
  queue_as :low

  def perform(account_id, ghl_contact_id)
    account = Account.find_by(id: account_id)
    return unless account

    hook = account.hooks.find_by(app_id: 'gohighlevel', status: 'enabled')
    return unless hook

    contact = account.contacts.find_by(identifier: "ghl:#{ghl_contact_id}") ||
              account.contacts.where("custom_attributes->>'ghl_contact_id' = ?", ghl_contact_id).first
    return unless contact

    # Fetch from GHL API
    ghl_data = fetch_ghl_contact(hook, ghl_contact_id)
    return unless ghl_data

    # Use the sync service to update
    sync = Ghl::ContactSyncService.new(account: account, hook: hook)
    sync.update_from_ghl({ 'contact' => ghl_data, 'locationId' => hook.reference_id })

    # Clear the pending enrichment flag
    custom = contact.reload.custom_attributes || {}
    custom.delete('ghl_pending_enrichment')
    contact.update_column(:custom_attributes, custom)

    Rails.logger.info("GHL enrichment: enriched contact #{contact.id} from GHL #{ghl_contact_id}")
  rescue StandardError => e
    Rails.logger.error("GHL enrichment failed for #{ghl_contact_id}: #{e.message}")
    # Don't re-raise — enrichment failure is non-critical
  end

  private

  def fetch_ghl_contact(hook, ghl_contact_id)
    uri = URI("https://services.leadconnectorhq.com/contacts/#{ghl_contact_id}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{hook.access_token}"
    request['Version'] = '2021-07-28'

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data['contact'] || data
  end
end
