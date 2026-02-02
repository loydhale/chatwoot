# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ghl::OpportunitySyncService, type: :service do
  let(:account) { create(:account) }
  let(:opportunity_params) do
    {
      'opportunity' => {
        'id' => 'opp_test_1',
        'name' => 'Website Redesign Project',
        'status' => 'open',
        'monetaryValue' => 15_000,
        'pipelineId' => 'pipe_1',
        'pipelineName' => 'Sales Pipeline',
        'stageId' => 'stage_1',
        'stageName' => 'Qualification',
        'contactId' => 'ghl_ct_1',
        'locationId' => 'loc_test',
        'source' => 'website'
      },
      'locationId' => 'loc_test'
    }
  end
  let(:hook) do
    create(:integrations_hook,
           account: account,
           app_id: 'gohighlevel',
           status: 'enabled',
           reference_id: 'loc_test')
  end
  let(:inbox) { create(:inbox, account: account, name: 'GHL Messages') }
  let(:service) { described_class.new(account: account, hook: hook) }

  before { inbox } # ensure inbox exists

  # ─── create_from_ghl ──────────────────────────────────────────────

  describe '#create_from_ghl' do
    it 'creates a conversation with opportunity metadata' do # rubocop:disable RSpec/MultipleExpectations
      conversation = service.create_from_ghl(opportunity_params)

      expect(conversation).to be_persisted
      expect(conversation.identifier).to eq('ghl_opp:opp_test_1')
      expect(conversation.status).to eq('open')
      expect(conversation.custom_attributes['ghl_opportunity_id']).to eq('opp_test_1')
      expect(conversation.custom_attributes['ghl_opportunity_name']).to eq('Website Redesign Project')
      expect(conversation.custom_attributes['ghl_opportunity_value']).to eq(15_000)
      expect(conversation.custom_attributes['ghl_opportunity_pipeline']).to eq('Sales Pipeline')
      expect(conversation.custom_attributes['ghl_opportunity_stage']).to eq('Qualification')
    end

    it 'creates the associated contact if not found' do
      expect do
        service.create_from_ghl(opportunity_params)
      end.to change(Contact, :count).by(1)

      contact = Contact.find_by(identifier: 'ghl:ghl_ct_1')
      expect(contact).to be_present
    end

    it 'reuses an existing contact linked to the GHL contact ID' do
      existing_contact = create(:contact,
                                account: account,
                                identifier: 'ghl:ghl_ct_1',
                                name: 'Jane Doe')

      conversation = service.create_from_ghl(opportunity_params)
      expect(conversation.contact).to eq(existing_contact)
    end

    it 'applies pipeline and stage labels' do
      conversation = service.create_from_ghl(opportunity_params)

      labels = conversation.label_list.to_a
      expect(labels).to include('ghl-opportunity')
      expect(labels.any? { |l| l.start_with?('pipeline:') }).to be true
      expect(labels.any? { |l| l.start_with?('stage:') }).to be true
    end

    it 'adds an initial activity note' do
      conversation = service.create_from_ghl(opportunity_params)

      note = conversation.messages.where(message_type: :activity, private: true).first
      expect(note).to be_present
      expect(note.content).to include('GHL Opportunity created')
      expect(note.content).to include('Website Redesign Project')
    end

    it 'is idempotent — updates existing conversation if opportunity already synced' do
      first = service.create_from_ghl(opportunity_params)

      updated_params = opportunity_params.deep_dup
      updated_params['opportunity']['monetaryValue'] = 20_000

      second = service.create_from_ghl(updated_params)
      expect(second.id).to eq(first.id)
      expect(second.custom_attributes['ghl_opportunity_value']).to eq(20_000)
    end

    it 'returns nil when opportunity ID is blank' do
      params = { 'opportunity' => { 'id' => '' } }
      expect(service.create_from_ghl(params)).to be_nil
    end

    it 'returns nil when no inbox exists' do
      Inbox.destroy_all

      result = service.create_from_ghl(opportunity_params)
      expect(result).to be_nil
    end
  end

  # ─── update_from_ghl ──────────────────────────────────────────────

  describe '#update_from_ghl' do
    it 'updates existing conversation attributes' do
      conversation = service.create_from_ghl(opportunity_params)

      updated_params = opportunity_params.deep_dup
      updated_params['opportunity']['monetaryValue'] = 25_000
      updated_params['opportunity']['stageName'] = 'Proposal'

      service.update_from_ghl(updated_params)
      conversation.reload

      expect(conversation.custom_attributes['ghl_opportunity_value']).to eq(25_000)
      expect(conversation.custom_attributes['ghl_opportunity_stage']).to eq('Proposal')
    end

    it 'adds a stage-change note when stage changes' do
      service.create_from_ghl(opportunity_params)

      updated_params = opportunity_params.deep_dup
      updated_params['opportunity']['stageName'] = 'Negotiation'

      service.update_from_ghl(updated_params)

      conversation = account.conversations.find_by(identifier: 'ghl_opp:opp_test_1')
      notes = conversation.messages.where(message_type: :activity, private: true)
      stage_note = notes.find { |n| n.content.include?('stage changed') }
      expect(stage_note).to be_present
      expect(stage_note.content).to include('Qualification')
      expect(stage_note.content).to include('Negotiation')
    end

    it 'creates conversation if not found (fallback to create)' do
      expect do
        service.update_from_ghl(opportunity_params)
      end.to change(Conversation, :count).by(1)
    end
  end

  # ─── delete_from_ghl ──────────────────────────────────────────────

  describe '#delete_from_ghl' do
    it 'resolves the conversation and adds deletion note' do
      conversation = service.create_from_ghl(opportunity_params)
      expect(conversation.status).to eq('open')

      service.delete_from_ghl(opportunity_params)
      conversation.reload

      expect(conversation.status).to eq('resolved')
      notes = conversation.messages.where(message_type: :activity, private: true)
      delete_note = notes.find { |n| n.content.include?('deleted') }
      expect(delete_note).to be_present
    end

    it 'returns nil when conversation is not found' do
      result = service.delete_from_ghl('opportunity' => { 'id' => 'nonexistent' })
      expect(result).to be_nil
    end
  end

  # ─── status_change_from_ghl ───────────────────────────────────────

  describe '#status_change_from_ghl' do
    it 'updates conversation status to resolved for won opportunity' do
      conversation = service.create_from_ghl(opportunity_params)

      won_params = opportunity_params.deep_dup
      won_params['opportunity']['status'] = 'won'

      service.status_change_from_ghl(won_params)
      conversation.reload

      expect(conversation.status).to eq('resolved')
    end

    it 'updates conversation status to resolved for lost opportunity' do
      conversation = service.create_from_ghl(opportunity_params)

      lost_params = opportunity_params.deep_dup
      lost_params['opportunity']['status'] = 'lost'

      service.status_change_from_ghl(lost_params)
      expect(conversation.reload.status).to eq('resolved')
    end

    it 'adds a status-change note' do
      conversation = service.create_from_ghl(opportunity_params)

      won_params = opportunity_params.deep_dup
      won_params['opportunity']['status'] = 'won'

      service.status_change_from_ghl(won_params)

      notes = conversation.messages.where(message_type: :activity, private: true)
      status_note = notes.find { |n| n.content.include?('status changed') }
      expect(status_note).to be_present
    end

    it 'does nothing when opportunity ID is blank' do
      result = service.status_change_from_ghl('opportunity' => { 'id' => '' })
      expect(result).to be_nil
    end
  end
end
