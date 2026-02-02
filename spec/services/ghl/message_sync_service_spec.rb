# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ghl::MessageSyncService, type: :service do
  let(:account) { create(:account) }
  let(:hook) do
    create(:integrations_hook,
           account: account,
           app_id: 'gohighlevel',
           status: 'enabled',
           reference_id: 'loc_test')
  end
  let(:inbox) { create(:inbox, account: account, name: 'GHL Messages') }
  let(:contact) do
    create(:contact,
           account: account,
           identifier: 'ghl:ghl_ct_1',
           name: 'Test User',
           custom_attributes: { 'ghl_contact_id' => 'ghl_ct_1' })
  end
  let(:service) { described_class.new(account: account, hook: hook) }

  before { inbox && contact } # ensure they exist

  # ─── process_message ───────────────────────────────────────────────

  describe '#process_message' do
    let(:inbound_params) do
      {
        'type' => 'InboundMessage',
        'locationId' => 'loc_test',
        'message' => {
          'id' => 'msg_ghl_1',
          'body' => 'Hi, I need help with my account',
          'direction' => 'inbound',
          'contactId' => 'ghl_ct_1',
          'conversationId' => 'conv_ghl_1',
          'dateAdded' => Time.current.iso8601,
          'contentType' => 'text'
        }
      }
    end

    it 'creates a message in a new conversation' do
      message = service.process_message(inbound_params)

      expect(message).to be_persisted
      expect(message.content).to eq('Hi, I need help with my account')
      expect(message.message_type).to eq('incoming')
      expect(message.source_id).to eq('msg_ghl_1')
      expect(message.conversation).to be_present
    end

    it 'creates a conversation linked to the GHL conversation ID' do
      service.process_message(inbound_params)

      conversation = account.conversations.find_by(identifier: 'ghl:conv_ghl_1')
      expect(conversation).to be_present
      expect(conversation.contact).to eq(contact)
      expect(conversation.inbox).to eq(inbox)
    end

    it 'appends to an existing conversation' do
      # First message creates conversation
      service.process_message(inbound_params)

      # Second message should append
      second_params = inbound_params.deep_dup
      second_params['message']['id'] = 'msg_ghl_2'
      second_params['message']['body'] = 'Follow-up question'

      message = service.process_message(second_params)

      conversation = account.conversations.find_by(identifier: 'ghl:conv_ghl_1')
      expect(conversation.messages.count).to eq(2)
      expect(message.content).to eq('Follow-up question')
    end

    it 'handles outbound messages correctly' do
      outbound_params = inbound_params.deep_dup
      outbound_params['type'] = 'OutboundMessage'
      outbound_params['message']['direction'] = 'outbound'
      outbound_params['message']['id'] = 'msg_ghl_out_1'

      message = service.process_message(outbound_params)
      expect(message.message_type).to eq('outgoing')
    end

    it 'is idempotent — skips already-synced messages' do
      service.process_message(inbound_params)

      # Replay same message
      result = service.process_message(inbound_params)
      expect(result).to be_nil # skipped

      expect(account.messages.where(source_id: 'msg_ghl_1').count).to eq(1)
    end

    it 'creates a placeholder contact if not found' do
      new_params = inbound_params.deep_dup
      new_params['message']['contactId'] = 'ghl_ct_new_unknown'

      message = service.process_message(new_params)

      expect(message).to be_present
      new_contact = Contact.find_by(identifier: 'ghl:ghl_ct_new_unknown')
      expect(new_contact).to be_present
      expect(new_contact.custom_attributes['ghl_pending_enrichment']).to be(true)
    end

    it 'returns nil when message has no ID' do
      params = { 'message' => { 'id' => nil, 'body' => 'test' }, 'locationId' => 'loc_test' }
      expect(service.process_message(params)).to be_nil
    end

    it 'stores GHL metadata in message additional_attributes' do
      message = service.process_message(inbound_params)

      expect(message.additional_attributes['ghl_message_id']).to eq('msg_ghl_1')
      expect(message.additional_attributes['ghl_conversation_id']).to eq('conv_ghl_1')
      expect(message.additional_attributes['ghl_synced_at']).to be_present
    end
  end

  # ─── sync_conversation_status ──────────────────────────────────────

  describe '#sync_conversation_status' do
    it 'updates conversation status to resolved for closed GHL conversation' do
      # First create a conversation
      service.process_message(
        'locationId' => 'loc_test',
        'message' => {
          'id' => 'msg_init',
          'body' => 'Initial message',
          'direction' => 'inbound',
          'contactId' => 'ghl_ct_1',
          'conversationId' => 'conv_status_1'
        }
      )

      service.sync_conversation_status(
        'conversation' => { 'id' => 'conv_status_1', 'status' => 'closed' },
        'locationId' => 'loc_test'
      )

      conversation = account.conversations.find_by(identifier: 'ghl:conv_status_1')
      expect(conversation.status).to eq('resolved')
    end

    it 'does nothing for unknown conversation' do
      expect do
        service.sync_conversation_status(
          'conversation' => { 'id' => 'nonexistent', 'status' => 'closed' }
        )
      end.not_to raise_error
    end
  end
end
