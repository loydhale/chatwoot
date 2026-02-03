# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::GhlEventsJob, type: :job do
  let(:account) { create(:account) }
  let!(:hook) do
    create(:integrations_hook,
           account: account,
           app_id: 'gohighlevel',
           status: 'enabled',
           reference_id: 'loc_test_123',
           settings: { 'location_id' => 'loc_test_123' })
  end

  let(:base_params) { { 'locationId' => 'loc_test_123' } }

  # ─── Contact Events ────────────────────────────────────────────────

  describe 'contact.create' do
    let(:params) do
      base_params.merge(
        'contact' => {
          'id' => 'ghl_ct_1',
          'firstName' => 'Jane',
          'lastName' => 'Doe',
          'email' => 'jane@example.com',
          'phone' => '+12025551234',
          'locationId' => 'loc_test_123'
        }
      )
    end

    it 'delegates to ContactSyncService.create_from_ghl' do
      service = instance_double(Ghl::ContactSyncService)
      allow(Ghl::ContactSyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:create_from_ghl).with(params)

      described_class.new.perform('contact.create', params)
    end
  end

  describe 'contact.update' do
    let(:params) do
      base_params.merge('contact' => { 'id' => 'ghl_ct_1', 'email' => 'updated@test.com' })
    end

    it 'delegates to ContactSyncService.update_from_ghl' do
      service = instance_double(Ghl::ContactSyncService)
      allow(Ghl::ContactSyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:update_from_ghl).with(params)

      described_class.new.perform('contact.update', params)
    end
  end

  describe 'contact.delete' do
    let(:params) do
      base_params.merge('contact' => { 'id' => 'ghl_ct_1' })
    end

    it 'delegates to ContactSyncService.delete_from_ghl' do
      service = instance_double(Ghl::ContactSyncService)
      allow(Ghl::ContactSyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:delete_from_ghl).with(params)

      described_class.new.perform('contact.delete', params)
    end
  end

  # ─── Message Events ────────────────────────────────────────────────

  describe 'conversation.message' do
    let(:params) do
      base_params.merge(
        'message' => {
          'id' => 'msg_1',
          'body' => 'Hello world',
          'direction' => 'inbound',
          'contactId' => 'ghl_ct_1',
          'conversationId' => 'conv_1'
        }
      )
    end

    it 'delegates to MessageSyncService.process_message' do
      service = instance_double(Ghl::MessageSyncService)
      allow(Ghl::MessageSyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:process_message).with(params)

      described_class.new.perform('conversation.message', params)
    end
  end

  describe 'conversation.status' do
    let(:params) do
      base_params.merge('conversation' => { 'id' => 'conv_1', 'status' => 'closed' })
    end

    it 'delegates to MessageSyncService.sync_conversation_status' do
      service = instance_double(Ghl::MessageSyncService)
      allow(Ghl::MessageSyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:sync_conversation_status).with(params)

      described_class.new.perform('conversation.status', params)
    end
  end

  # ─── Opportunity Events ────────────────────────────────────────────

  describe 'opportunity.create' do
    let(:params) do
      base_params.merge(
        'opportunity' => {
          'id' => 'opp_1',
          'name' => 'Big Deal',
          'monetaryValue' => 50_000,
          'pipelineName' => 'Sales Pipeline',
          'stageName' => 'Qualification',
          'contactId' => 'ghl_ct_1',
          'status' => 'open'
        }
      )
    end

    it 'delegates to OpportunitySyncService.create_from_ghl' do
      service = instance_double(Ghl::OpportunitySyncService)
      allow(Ghl::OpportunitySyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:create_from_ghl).with(params)

      described_class.new.perform('opportunity.create', params)
    end
  end

  describe 'opportunity.update' do
    let(:params) do
      base_params.merge(
        'opportunity' => { 'id' => 'opp_1', 'monetaryValue' => 75_000, 'stageName' => 'Negotiation' }
      )
    end

    it 'delegates to OpportunitySyncService.update_from_ghl' do
      service = instance_double(Ghl::OpportunitySyncService)
      allow(Ghl::OpportunitySyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:update_from_ghl).with(params)

      described_class.new.perform('opportunity.update', params)
    end
  end

  describe 'opportunity.delete' do
    let(:params) do
      base_params.merge('opportunity' => { 'id' => 'opp_1' })
    end

    it 'delegates to OpportunitySyncService.delete_from_ghl' do
      service = instance_double(Ghl::OpportunitySyncService)
      allow(Ghl::OpportunitySyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:delete_from_ghl).with(params)

      described_class.new.perform('opportunity.delete', params)
    end
  end

  describe 'opportunity.status_change' do
    let(:params) do
      base_params.merge(
        'opportunity' => { 'id' => 'opp_1', 'status' => 'won', 'stageName' => 'Closed Won' }
      )
    end

    it 'delegates to OpportunitySyncService.status_change_from_ghl' do
      service = instance_double(Ghl::OpportunitySyncService)
      allow(Ghl::OpportunitySyncService).to receive(:new).with(account: account, hook: hook).and_return(service)
      expect(service).to receive(:status_change_from_ghl).with(params)

      described_class.new.perform('opportunity.status_change', params)
    end
  end

  # ─── App Lifecycle Events ──────────────────────────────────────────

  describe 'app.installed' do
    it 'handles app installation without requiring a hook' do
      params = { 'locationId' => 'loc_new_install', 'companyId' => 'comp_1' }

      # Should not raise even though no hook exists for loc_new_install
      expect { described_class.new.perform('app.installed', params) }.not_to raise_error
    end

    it 'reactivates suspended subscription on reinstall' do
      sub = create(:ghl_subscription, account: account, status: 'suspended')
      account.update!(ghl_location_id: 'loc_test_123')

      params = { 'locationId' => 'loc_test_123', 'companyId' => 'comp_1' }
      described_class.new.perform('app.installed', params)

      expect(sub.reload.status).to eq('active')
    end
  end

  describe 'app.uninstalled' do
    it 'disables hook and suspends subscription' do
      sub = create(:ghl_subscription, account: account, status: 'active')

      params = base_params.merge('companyId' => 'comp_1')
      described_class.new.perform('app.uninstalled', params)

      expect(hook.reload.status).to eq('disabled')
      expect(sub.reload.status).to eq('suspended')
    end
  end

  # ─── Location Events ───────────────────────────────────────────────

  describe 'location.create' do
    it 'increments location count on subscription' do
      sub = create(:ghl_subscription, account: account, locations_count: 1, locations_limit: 5)

      params = base_params.merge('location' => { 'id' => 'loc_new' })
      described_class.new.perform('location.create', params)

      expect(sub.reload.locations_count).to eq(2)
    end
  end

  # ─── Missing Hook ──────────────────────────────────────────────────

  describe 'missing hook' do
    it 'logs warning and returns gracefully when no hook found' do
      params = { 'locationId' => 'nonexistent_location', 'contact' => { 'id' => 'ct_1' } }

      expect(Rails.logger).to receive(:warn).with(/no integration found/)
      expect { described_class.new.perform('contact.create', params) }.not_to raise_error
    end
  end

  # ─── Error Handling ────────────────────────────────────────────────

  describe 'error handling' do
    it 're-raises errors for Sidekiq retry' do
      service = instance_double(Ghl::ContactSyncService)
      allow(Ghl::ContactSyncService).to receive(:new).and_return(service)
      allow(service).to receive(:create_from_ghl).and_raise(StandardError, 'DB connection lost')

      params = base_params.merge('contact' => { 'id' => 'ct_1' })

      expect { described_class.new.perform('contact.create', params) }.to raise_error(StandardError, 'DB connection lost')
    end
  end
end
