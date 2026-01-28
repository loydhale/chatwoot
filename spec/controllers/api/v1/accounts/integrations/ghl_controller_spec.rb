# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Integrations::GhlController', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/integrations/ghl/status' do
    context 'when GHL is not connected' do
      it 'returns connected: false' do
        get "/api/v1/accounts/#{account.id}/integrations/ghl/status",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['connected']).to be(false)
      end
    end

    context 'when GHL is connected' do
      let!(:hook) do
        create(:integrations_hook,
               account: account,
               app_id: 'gohighlevel',
               settings: {
                 'location_id' => 'loc123',
                 'company_id' => 'comp456',
                 'connected_at' => Time.current.iso8601,
                 'expires_at' => 1.day.from_now.iso8601
               })
      end

      it 'returns connection details' do
        get "/api/v1/accounts/#{account.id}/integrations/ghl/status",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['connected']).to be(true)
        expect(json_response['location_id']).to eq('loc123')
        expect(json_response['company_id']).to eq('comp456')
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/integrations/ghl/refresh' do
    let!(:hook) do
      create(:integrations_hook,
             account: account,
             app_id: 'gohighlevel',
             settings: {
               'refresh_token' => 'old_refresh_token',
               'expires_at' => 1.hour.ago.iso8601
             })
    end

    context 'when user is an administrator' do
      before do
        create(:installation_config, name: 'GHL_CLIENT_ID', value: 'test_client_id')
        create(:installation_config, name: 'GHL_CLIENT_SECRET', value: 'test_client_secret')

        # Stub OAuth2 token refresh
        allow_any_instance_of(OAuth2::AccessToken).to receive(:refresh!).and_return(
          instance_double(OAuth2::AccessToken,
                          to_hash: {
                            'access_token' => 'new_access_token',
                            'refresh_token' => 'new_refresh_token',
                            'expires_in' => 86_400
                          })
        )
      end

      it 'refreshes the token' do
        post "/api/v1/accounts/#{account.id}/integrations/ghl/refresh",
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be(true)
      end
    end

    context 'when user is not an administrator' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/integrations/ghl/refresh",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/integrations/ghl' do
    let!(:hook) do
      create(:integrations_hook, account: account, app_id: 'gohighlevel')
    end

    context 'when user is an administrator' do
      it 'deletes the integration' do
        expect do
          delete "/api/v1/accounts/#{account.id}/integrations/ghl",
                 headers: admin.create_new_auth_token,
                 as: :json
        end.to change(Integrations::Hook, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when user is not an administrator' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/integrations/ghl",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when integration does not exist' do
      before { hook.destroy }

      it 'returns not found' do
        delete "/api/v1/accounts/#{account.id}/integrations/ghl",
               headers: admin.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
