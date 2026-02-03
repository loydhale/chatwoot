# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ghl::CallbacksController, type: :request do
  let(:account) { create(:account) }
  let(:code) { SecureRandom.hex(10) }
  let(:state) { SecureRandom.hex(10) }
  let(:frontend_url) { 'http://www.example.com' }
  let(:ghl_redirect_uri) { "#{frontend_url}/app/accounts/#{account.id}/settings/integrations/gohighlevel" }
  let(:oauth_client) { instance_double(OAuth2::Client) }
  let(:auth_code_strategy) { instance_double(OAuth2::Strategy::AuthCode) }
  let(:access_token) { SecureRandom.hex(20) }
  let(:refresh_token) { SecureRandom.hex(20) }
  let(:location_id) { SecureRandom.hex(10) }
  let(:company_id) { SecureRandom.hex(10) }
  let(:token_response) do
    instance_double(
      OAuth2::AccessToken,
      response: instance_double(OAuth2::Response, parsed: response_body),
      token: access_token
    )
  end

  describe 'GET /ghl/callback' do
    let(:response_body) do
      {
        'access_token' => access_token,
        'refresh_token' => refresh_token,
        'token_type' => 'Bearer',
        'expires_in' => 86_400,
        'scope' => 'contacts.readonly contacts.write',
        'userType' => 'Location',
        'locationId' => location_id,
        'companyId' => company_id,
        'userId' => 'user123'
      }
    end

    before do
      stub_const('ENV', ENV.to_hash.merge('FRONTEND_URL' => frontend_url))
    end

    shared_context 'with stubbed account' do
      before do
        allow_any_instance_of(described_class).to receive(:verify_ghl_token).and_return(account.id)
        allow_any_instance_of(described_class).to receive(:ghl_client).and_return(oauth_client)
        allow(Account).to receive(:find_by).with(id: account.id).and_return(account)
        allow(oauth_client).to receive(:auth_code).and_return(auth_code_strategy)
      end
    end

    context 'when successful' do
      include_context 'with stubbed account'

      before do
        allow(auth_code_strategy).to receive(:get_token).and_return(token_response)
      end

      it 'creates a new integration hook' do
        expect do
          get ghl_callback_path, params: { code: code, state: state }
        end.to change(Integrations::Hook, :count).by(1)

        hook = Integrations::Hook.last
        expect(hook.access_token).to eq(access_token)
        expect(hook.app_id).to eq('gohighlevel')
        expect(hook.status).to eq('enabled')
        expect(hook.reference_id).to eq(location_id)
        expect(hook.settings['location_id']).to eq(location_id)
        expect(hook.settings['company_id']).to eq(company_id)
        expect(hook.refresh_token).to eq(refresh_token)
        expect(hook.settings).not_to have_key('refresh_token')
        expect(response).to redirect_to(ghl_redirect_uri)
      end

      it 'updates existing hook if present' do
        existing_hook = create(:integrations_hook, account: account, app_id: 'gohighlevel')

        expect do
          get ghl_callback_path, params: { code: code, state: state }
        end.not_to change(Integrations::Hook, :count)

        existing_hook.reload
        expect(existing_hook.access_token).to eq(access_token)
        expect(existing_hook.settings['location_id']).to eq(location_id)
      end
    end

    context 'when the code is invalid' do
      include_context 'with stubbed account'

      before do
        allow(auth_code_strategy).to receive(:get_token).and_raise(StandardError.new('invalid_grant'))
      end

      it 'redirects with error' do
        get ghl_callback_path, params: { code: code, state: state }
        expect(response).to redirect_to("#{frontend_url}/app/settings/integrations/gohighlevel?error=unknown")
      end
    end

    context 'when state parameter is invalid' do
      before do
        allow_any_instance_of(described_class).to receive(:verify_ghl_token).and_return(nil)
      end

      it 'redirects with invalid_state error BEFORE exchanging the code' do
        get ghl_callback_path, params: { code: code, state: state }
        expect(response).to redirect_to("#{frontend_url}/app/settings/integrations/gohighlevel?error=invalid_state")
      end
    end
  end
end
