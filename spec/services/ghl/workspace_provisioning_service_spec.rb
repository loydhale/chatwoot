# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ghl::WorkspaceProvisioningService do
  let(:oauth_data) do
    {
      'access_token' => 'ghl_test_token_123',
      'token_type' => 'Bearer',
      'expires_in' => 86_400,
      'refresh_token' => 'ghl_refresh_token_456',
      'scope' => 'contacts.readonly contacts.write conversations.readonly conversations.write',
      'userType' => 'Location',
      'locationId' => 'loc_abc123',
      'companyId' => 'comp_xyz789',
      'userId' => 'user_def456',
      'appId' => 'app_test_001'
    }
  end

  let(:ghl_user_info) do
    {
      'companyName' => 'Test Agency',
      'locationName' => 'Test Location',
      'email' => 'admin@testagency.com',
      'name' => 'John Smith'
    }
  end

  subject(:service) do
    described_class.new(oauth_data: oauth_data, ghl_user_info: ghl_user_info)
  end

  describe '#perform' do
    context 'when creating a new workspace' do
      it 'creates an account' do
        result = service.perform
        expect(result.success?).to be true
        expect(result.account).to be_persisted
        expect(result.account.name).to eq('Test Agency')
        expect(result.account.ghl_location_id).to eq('loc_abc123')
        expect(result.account.ghl_company_id).to eq('comp_xyz789')
      end

      it 'creates an admin user' do
        result = service.perform
        expect(result.user).to be_persisted
        expect(result.user.email).to eq('admin@testagency.com')
        expect(result.user.name).to eq('John Smith')

        # User should be admin of the account
        account_user = AccountUser.find_by(user: result.user, account: result.account)
        expect(account_user.role).to eq('administrator')
      end

      it 'creates a subscription with trial' do
        result = service.perform
        expect(result.subscription).to be_persisted
        expect(result.subscription.plan).to eq('starter')
        expect(result.subscription.status).to eq('trialing')
        expect(result.subscription.ghl_location_id).to eq('loc_abc123')
        expect(result.subscription.trial_ends_at).to be > Time.current
      end

      it 'creates an integration hook' do
        result = service.perform
        expect(result.hook).to be_persisted
        expect(result.hook.app_id).to eq('gohighlevel')
        expect(result.hook.status).to eq('enabled')
        expect(result.hook.reference_id).to eq('loc_abc123')
      end

      it 'creates a default inbox' do
        result = service.perform
        expect(result.account.inboxes.count).to eq(1)
        expect(result.account.inboxes.first.name).to eq('GHL Messages')
      end
    end

    context 'when workspace already exists (re-install)' do
      let!(:existing_account) do
        Account.create!(name: 'Existing', ghl_location_id: 'loc_abc123')
      end

      it 'reconnects to the existing account' do
        result = service.perform
        expect(result.success?).to be true
        expect(result.account.id).to eq(existing_account.id)
      end

      it 'does not create a duplicate account' do
        expect { service.perform }.not_to change(Account, :count)
      end
    end

    context 'without user info' do
      let(:ghl_user_info) { {} }

      it 'uses fallback values' do
        result = service.perform
        expect(result.success?).to be true
        expect(result.account.name).to eq('DeskFlows Workspace')
        expect(result.user.email).to match(/ghl-user_def456@deskflows\.ai/)
      end
    end
  end
end
