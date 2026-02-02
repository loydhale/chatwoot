# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ghl::ContactSyncService, type: :service do
  let(:account) { create(:account) }
  let(:hook) do
    create(:integrations_hook,
           account: account,
           app_id: 'gohighlevel',
           status: 'enabled',
           reference_id: 'loc_test')
  end
  let(:service) { described_class.new(account: account, hook: hook) }

  let(:contact_params) do
    {
      'contact' => {
        'id' => 'ghl_ct_100',
        'firstName' => 'John',
        'lastName' => 'Smith',
        'email' => 'john@example.com',
        'phone' => '+14155551234',
        'locationId' => 'loc_test',
        'source' => 'website',
        'tags' => %w[vip prospect],
        'companyName' => 'Acme Corp',
        'city' => 'Austin',
        'state' => 'TX'
      },
      'locationId' => 'loc_test'
    }
  end

  # ─── create_from_ghl ──────────────────────────────────────────────

  describe '#create_from_ghl' do
    it 'creates a new DeskFlows contact from GHL data' do
      contact = service.create_from_ghl(contact_params)

      expect(contact).to be_persisted
      expect(contact.name).to eq('John Smith')
      expect(contact.email).to eq('john@example.com')
      expect(contact.phone_number).to eq('+14155551234')
      expect(contact.identifier).to eq('ghl:ghl_ct_100')
    end

    it 'stores GHL metadata in custom_attributes' do
      contact = service.create_from_ghl(contact_params)

      expect(contact.custom_attributes['ghl_contact_id']).to eq('ghl_ct_100')
      expect(contact.custom_attributes['ghl_location_id']).to eq('loc_test')
      expect(contact.custom_attributes['ghl_source']).to eq('website')
      expect(contact.custom_attributes['ghl_tags']).to eq(%w[vip prospect])
    end

    it 'stores company info in additional_attributes' do
      contact = service.create_from_ghl(contact_params)

      expect(contact.additional_attributes['company_name']).to eq('Acme Corp')
      expect(contact.additional_attributes['city']).to eq('Austin')
      expect(contact.additional_attributes['state']).to eq('TX')
    end

    it 'does not create duplicates — updates if GHL ID already exists' do
      existing = create(:contact,
                        account: account,
                        identifier: 'ghl:ghl_ct_100',
                        name: 'Old Name')

      result = service.create_from_ghl(contact_params)
      expect(result.id).to eq(existing.id)
      expect(result.name).to eq('John Smith')
    end

    it 'normalizes phone numbers to E.164 format' do
      params = contact_params.deep_dup
      params['contact']['phone'] = '14155551234' # missing +

      contact = service.create_from_ghl(params)
      expect(contact.phone_number).to eq('+14155551234')
    end

    it 'handles contacts with only an email' do
      params = { 'contact' => { 'id' => 'ghl_ct_email', 'email' => 'only@email.com' } }
      contact = service.create_from_ghl(params)

      expect(contact).to be_persisted
      expect(contact.email).to eq('only@email.com')
    end

    it 'returns nil for blank contact ID' do
      result = service.create_from_ghl('contact' => { 'id' => '' })
      expect(result).to be_nil
    end

    it 'links to existing contact when email conflicts' do
      existing = create(:contact, account: account, email: 'john@example.com', name: 'Existing John')

      contact = service.create_from_ghl(contact_params)

      # Should link to existing rather than failing
      expect(contact).to be_present
      expect(contact.custom_attributes['ghl_contact_id']).to eq('ghl_ct_100')
    end
  end

  # ─── update_from_ghl ──────────────────────────────────────────────

  describe '#update_from_ghl' do
    it 'updates an existing contact' do
      create(:contact,
             account: account,
             identifier: 'ghl:ghl_ct_100',
             name: 'Old Name',
             email: 'old@email.com')

      contact = service.update_from_ghl(contact_params)

      expect(contact.name).to eq('John Smith')
      expect(contact.email).to eq('john@example.com')
    end

    it 'merges custom_attributes rather than overwriting' do
      existing = create(:contact,
                        account: account,
                        identifier: 'ghl:ghl_ct_100',
                        custom_attributes: { 'existing_key' => 'keep_me' })

      service.update_from_ghl(contact_params)
      existing.reload

      expect(existing.custom_attributes['existing_key']).to eq('keep_me')
      expect(existing.custom_attributes['ghl_contact_id']).to eq('ghl_ct_100')
    end

    it 'creates the contact if not found' do
      expect do
        service.update_from_ghl(contact_params)
      end.to change(Contact, :count).by(1)
    end
  end

  # ─── delete_from_ghl ──────────────────────────────────────────────

  describe '#delete_from_ghl' do
    it 'soft-archives the contact instead of deleting' do
      contact = create(:contact,
                       account: account,
                       identifier: 'ghl:ghl_ct_100')

      service.delete_from_ghl(contact_params)
      contact.reload

      expect(contact.custom_attributes['ghl_deleted']).to be(true)
      expect(contact.custom_attributes['ghl_deleted_at']).to be_present
    end

    it 'returns nil when contact not found' do
      result = service.delete_from_ghl('contact' => { 'id' => 'nonexistent' })
      expect(result).to be_nil
    end
  end
end
