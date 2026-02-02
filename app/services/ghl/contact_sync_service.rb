# frozen_string_literal: true

class Ghl::ContactSyncService
  GHL_API_BASE = 'https://services.leadconnectorhq.com'

  attr_reader :account, :hook

  def initialize(account:, hook:)
    @account = account
    @hook = hook
  end

  # --- Inbound: GHL → DeskFlows ---

  def create_from_ghl(params)
    ghl_contact = extract_contact_data(params)
    return if ghl_contact['id'].blank?

    # Don't create duplicates
    existing = find_contact_by_ghl_id(ghl_contact['id'])
    return update_contact_attributes(existing, ghl_contact) if existing

    contact = account.contacts.create!(
      map_ghl_to_deskflow(ghl_contact).merge(
        identifier: ghl_identifier(ghl_contact['id'])
      )
    )

    Rails.logger.info("GHL sync: created contact #{contact.id} from GHL #{ghl_contact['id']}")
    contact
  rescue ActiveRecord::RecordInvalid => e
    # Handle uniqueness conflicts (email/phone already exists)
    handle_duplicate_contact(ghl_contact, e)
  end

  def update_from_ghl(params)
    ghl_contact = extract_contact_data(params)
    return if ghl_contact['id'].blank?

    contact = find_contact_by_ghl_id(ghl_contact['id'])
    unless contact
      Rails.logger.info("GHL sync: contact not found for GHL #{ghl_contact['id']}, creating instead")
      return create_from_ghl(params)
    end

    update_contact_attributes(contact, ghl_contact)
  end

  def delete_from_ghl(params)
    ghl_contact = extract_contact_data(params)
    ghl_id = ghl_contact['id']
    return if ghl_id.blank?

    contact = find_contact_by_ghl_id(ghl_id)
    unless contact
      Rails.logger.info("GHL sync: cannot delete — contact not found for GHL #{ghl_id}")
      return
    end

    # Soft-archive rather than hard delete
    custom = contact.custom_attributes || {}
    contact.update!(
      custom_attributes: custom.merge(
        'ghl_deleted' => true,
        'ghl_deleted_at' => Time.current.iso8601
      )
    )

    Rails.logger.info("GHL sync: archived contact #{contact.id} (GHL #{ghl_id})")
    contact
  end

  # --- Outbound: DeskFlows → GHL ---

  def push_to_ghl(contact)
    ghl_id = extract_ghl_id_from_contact(contact)

    if ghl_id.present?
      update_ghl_contact(ghl_id, contact)
    else
      create_ghl_contact(contact)
    end
  rescue StandardError => e
    Rails.logger.error("GHL sync: failed to push contact #{contact.id} to GHL: #{e.message}")
    nil
  end

  # --- Bulk Sync ---

  def import_all_contacts
    contacts = fetch_all_ghl_contacts
    imported = 0
    skipped = 0

    contacts.each do |ghl_contact|
      existing = find_contact_by_ghl_id(ghl_contact['id'])
      if existing
        update_contact_attributes(existing, ghl_contact)
        skipped += 1
      else
        create_from_ghl({ 'contact' => ghl_contact, 'locationId' => hook.reference_id })
        imported += 1
      end
    rescue StandardError => e
      Rails.logger.error("GHL sync: failed to import contact #{ghl_contact['id']}: #{e.message}")
    end

    { imported: imported, skipped: skipped, total: contacts.size }
  end

  private

  # --- Data Mapping ---

  def map_ghl_to_deskflow(ghl_contact)
    attrs = {
      name: build_name(ghl_contact),
      email: ghl_contact['email'].presence,
      phone_number: normalize_phone(ghl_contact['phone'] || ghl_contact['phoneNumber']),
      custom_attributes: build_custom_attributes(ghl_contact),
      additional_attributes: build_additional_attributes(ghl_contact)
    }

    # Only include non-blank values to avoid overwriting with nil
    attrs.compact_blank
  end

  def map_deskflow_to_ghl(contact)
    payload = {}
    payload['firstName'] = contact.name&.split&.first if contact.name.present?
    payload['lastName'] = contact.name&.split(' ', 2)&.last if contact.name.present? && contact.name.include?(' ')
    payload['email'] = contact.email if contact.email.present?
    payload['phone'] = contact.phone_number if contact.phone_number.present?
    payload['locationId'] = hook.reference_id

    # Push custom attributes back as tags or custom fields
    payload['tags'] = contact.custom_attributes['ghl_tags'] if contact.custom_attributes.present? && contact.custom_attributes['ghl_tags'].present?

    payload
  end

  def build_name(ghl_contact)
    parts = [
      ghl_contact['firstName'] || ghl_contact['first_name'],
      ghl_contact['lastName'] || ghl_contact['last_name']
    ].compact_blank

    parts.any? ? parts.join(' ') : (ghl_contact['name'] || ghl_contact['contactName'])
  end

  def normalize_phone(phone)
    return nil if phone.blank?

    # Ensure E.164 format
    phone = "+#{phone}" unless phone.start_with?('+')
    phone
  end

  def build_custom_attributes(ghl_contact)
    attrs = {
      'ghl_contact_id' => ghl_contact['id'],
      'ghl_location_id' => ghl_contact['locationId'],
      'ghl_source' => ghl_contact['source'],
      'ghl_type' => ghl_contact['type']
    }

    # Map GHL tags
    attrs['ghl_tags'] = ghl_contact['tags'] if ghl_contact['tags'].present?

    # Map any custom fields from GHL
    if ghl_contact['customFields'].present?
      ghl_contact['customFields'].each do |field|
        key = "ghl_cf_#{field['id'] || field['key']}"
        attrs[key] = field['value'] || field['fieldValue']
      end
    end

    attrs.compact_blank
  end

  def build_additional_attributes(ghl_contact)
    attrs = {}
    attrs['company_name'] = ghl_contact['companyName'] if ghl_contact['companyName'].present?
    attrs['city'] = ghl_contact['city'] if ghl_contact['city'].present?
    attrs['state'] = ghl_contact['state'] if ghl_contact['state'].present?
    attrs['country'] = ghl_contact['country'] if ghl_contact['country'].present?
    attrs['address'] = ghl_contact['address1'] if ghl_contact['address1'].present?
    attrs['website'] = ghl_contact['website'] if ghl_contact['website'].present?
    attrs
  end

  # --- Contact Lookup ---

  def ghl_identifier(ghl_id)
    "ghl:#{ghl_id}"
  end

  def find_contact_by_ghl_id(ghl_id)
    # Primary: look up by identifier
    contact = account.contacts.find_by(identifier: ghl_identifier(ghl_id))
    return contact if contact

    # Fallback: look up by custom_attributes
    account.contacts.where("custom_attributes->>'ghl_contact_id' = ?", ghl_id).first
  end

  def extract_ghl_id_from_contact(contact)
    # Check identifier first
    return contact.identifier.delete_prefix('ghl:') if contact.identifier&.start_with?('ghl:')

    # Fallback to custom attributes
    contact.custom_attributes&.dig('ghl_contact_id')
  end

  def extract_contact_data(params)
    # GHL sends contact data in various shapes
    params['contact'] || params['data'] || params
  end

  # --- Contact Updates ---

  def update_contact_attributes(contact, ghl_contact)
    mapped = map_ghl_to_deskflow(ghl_contact)

    # Merge custom_attributes and additional_attributes instead of overwriting
    mapped[:custom_attributes] = (contact.custom_attributes || {}).merge(mapped[:custom_attributes]) if mapped[:custom_attributes]
    mapped[:additional_attributes] = (contact.additional_attributes || {}).merge(mapped[:additional_attributes]) if mapped[:additional_attributes]

    contact.update!(mapped)
    Rails.logger.info("GHL sync: updated contact #{contact.id} from GHL #{ghl_contact['id']}")
    contact
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("GHL sync: failed to update contact #{contact.id}: #{e.message}")
    contact
  end

  def handle_duplicate_contact(ghl_contact, error)
    Rails.logger.warn("GHL sync: duplicate contact for GHL #{ghl_contact['id']}: #{error.message}")

    # Try to find by email or phone and link
    contact = find_by_email_or_phone(ghl_contact)
    if contact
      link_contact_to_ghl(contact, ghl_contact)
      return contact
    end

    nil
  end

  def find_by_email_or_phone(ghl_contact)
    email = ghl_contact['email']
    phone = normalize_phone(ghl_contact['phone'] || ghl_contact['phoneNumber'])

    contact = account.contacts.find_by(email: email) if email.present?
    contact ||= account.contacts.find_by(phone_number: phone) if phone.present?
    contact
  end

  def link_contact_to_ghl(contact, ghl_contact)
    custom = (contact.custom_attributes || {}).merge(build_custom_attributes(ghl_contact))

    updates = { custom_attributes: custom }
    updates[:identifier] = ghl_identifier(ghl_contact['id']) if contact.identifier.blank?

    contact.update!(updates)
    Rails.logger.info("GHL sync: linked existing contact #{contact.id} to GHL #{ghl_contact['id']}")
  end

  # --- GHL API Calls (Outbound) ---

  def create_ghl_contact(contact)
    response = ghl_api_request(:post, '/contacts/', map_deskflow_to_ghl(contact))
    ghl_id = response.dig('contact', 'id')

    if ghl_id.present?
      contact.update!(
        identifier: ghl_identifier(ghl_id),
        custom_attributes: (contact.custom_attributes || {}).merge('ghl_contact_id' => ghl_id)
      )
      Rails.logger.info("GHL sync: created GHL contact #{ghl_id} for contact #{contact.id}")
    end

    response
  end

  def update_ghl_contact(ghl_id, contact)
    response = ghl_api_request(:put, "/contacts/#{ghl_id}", map_deskflow_to_ghl(contact))
    Rails.logger.info("GHL sync: updated GHL contact #{ghl_id} for contact #{contact.id}")
    response
  end

  def fetch_all_ghl_contacts
    contacts = []
    offset = 0
    limit = 100

    loop do
      response = ghl_api_request(:get, '/contacts/', nil, { locationId: hook.reference_id, limit: limit, offset: offset })
      batch = response['contacts'] || []
      contacts.concat(batch)
      break if batch.size < limit

      offset += limit
    end

    contacts
  end

  def ghl_api_request(method, path, body = nil, query = nil)
    uri = URI("#{GHL_API_BASE}#{path}")
    uri.query = URI.encode_www_form(query) if query.present?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = build_http_request(method, uri, body)
    request['Authorization'] = "Bearer #{hook.access_token}"
    request['Content-Type'] = 'application/json'
    request['Version'] = '2021-07-28'

    response = http.request(request)

    raise "GHL API #{method.upcase} #{path} failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def build_http_request(method, uri, body)
    case method
    when :get
      Net::HTTP::Get.new(uri)
    when :post
      req = Net::HTTP::Post.new(uri)
      req.body = body.to_json if body
      req
    when :put
      req = Net::HTTP::Put.new(uri)
      req.body = body.to_json if body
      req
    when :delete
      Net::HTTP::Delete.new(uri)
    end
  end
end
