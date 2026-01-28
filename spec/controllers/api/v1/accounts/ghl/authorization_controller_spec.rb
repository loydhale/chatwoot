# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ghl::AuthorizationController', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:frontend_url) { 'http://www.example.com' }

  before do
    stub_const('ENV', ENV.to_hash.merge('FRONTEND_URL' => frontend_url))
  end

  describe 'POST /api/v1/accounts/:account_id/ghl/authorization' do
    context 'when GHL credentials are configured' do
      before do
        create(:installation_config, name: 'GHL_CLIENT_ID', value: 'test_client_id')
        create(:installation_config, name: 'GHL_CLIENT_SECRET', value: 'test_client_secret')
      end

      context 'when user is an administrator' do
        it 'returns authorization URL' do
          post "/api/v1/accounts/#{account.id}/ghl/authorization",
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:ok)
          json_response = response.parsed_body
          expect(json_response['success']).to be(true)
          expect(json_response['url']).to include('marketplace.gohighlevel.com/oauth/chooselocation')
          expect(json_response['url']).to include('client_id=test_client_id')
          expect(json_response['url']).to include('response_type=code')
        end
      end

      context 'when user is not an administrator' do
        it 'returns unauthorized' do
          post "/api/v1/accounts/#{account.id}/ghl/authorization",
               headers: agent.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'when user is not authenticated' do
        it 'returns unauthorized' do
          post "/api/v1/accounts/#{account.id}/ghl/authorization", as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when GHL credentials are not configured' do
      it 'returns an error' do
        post "/api/v1/accounts/#{account.id}/ghl/authorization",
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['success']).to be(false)
        expect(json_response['error']).to include('not configured')
      end
    end
  end
end
