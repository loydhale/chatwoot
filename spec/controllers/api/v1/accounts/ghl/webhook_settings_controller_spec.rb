# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ghl::WebhookSettingsController', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ghl/webhook_settings" }

  # ─── GET /webhook_settings (show) ──────────────────────────────────

  describe 'GET /api/v1/accounts/:account_id/ghl/webhook_settings' do
    context 'when user is an administrator' do
      it 'returns webhook configuration' do
        get base_url, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['webhook_url']).to include('/webhooks/ghl')
        expect(json['events_enabled']).to be_an(Array)
        expect(json['events_enabled']).to include('contact.create', 'opportunity.create')
      end

      it 'shows GHL connection status when hook exists' do
        create(:integrations_hook,
               account: account,
               app_id: 'gohighlevel',
               reference_id: 'loc_123')

        get base_url, headers: admin.create_new_auth_token, as: :json

        json = response.parsed_body
        expect(json['ghl_connected']).to be(true)
        expect(json['ghl_location_id']).to eq('loc_123')
      end

      it 'shows webhook secret status when configured' do
        create(:installation_config, name: 'GHL_WEBHOOK_SECRET', value: 'secret_test_12345678')

        get base_url, headers: admin.create_new_auth_token, as: :json

        json = response.parsed_body
        expect(json['webhook_secret_configured']).to be(true)
        expect(json['webhook_secret_preview']).to include('...')
        # Should NOT expose the full secret
        expect(json['webhook_secret_preview'].length).to be < 20
      end

      it 'shows not configured when no secret is set' do
        GlobalConfig.clear_cache
        get base_url, headers: admin.create_new_auth_token, as: :json

        json = response.parsed_body
        expect(json['webhook_secret_configured']).to be(false)
      end
    end

    context 'when user is an agent' do
      it 'returns unauthorized' do
        get base_url, headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── POST /webhook_settings (create) ───────────────────────────────

  describe 'POST /api/v1/accounts/:account_id/ghl/webhook_settings' do
    context 'when user is an administrator' do
      it 'updates enabled events' do
        events = %w[contact.create contact.update opportunity.create]

        post base_url,
             params: { events: events },
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['success']).to be(true)
        expect(json['events_enabled']).to match_array(events)

        # Verify persisted
        account.reload
        expect(account.custom_attributes['ghl_webhook_events']).to match_array(events)
      end

      it 'filters out invalid event types' do
        events = %w[contact.create invalid.event opportunity.create]

        post base_url,
             params: { events: events },
             headers: admin.create_new_auth_token,
             as: :json

        json = response.parsed_body
        expect(json['events_enabled']).not_to include('invalid.event')
        expect(json['events_enabled']).to include('contact.create', 'opportunity.create')
      end
    end

    context 'when user is an agent' do
      it 'returns unauthorized' do
        post base_url,
             params: { events: ['contact.create'] },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── PUT /webhook_settings (update — regenerate secret) ────────────

  describe 'PUT /api/v1/accounts/:account_id/ghl/webhook_settings' do
    context 'when user is an administrator' do
      it 'regenerates webhook secret' do
        put base_url,
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['success']).to be(true)
        expect(json['webhook_secret']).to be_present
        expect(json['webhook_secret'].length).to eq(64) # hex(32) = 64 chars

        # Verify it's actually stored
        stored = InstallationConfig.find_by(name: 'GHL_WEBHOOK_SECRET')
        expect(stored).to be_present
        expect(stored.value).to eq(json['webhook_secret'])
      end
    end

    context 'when user is an agent' do
      it 'returns unauthorized' do
        put base_url,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
