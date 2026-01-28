# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ghl::IntegrationHelper do
  let(:helper_class) do
    Class.new do
      include Ghl::IntegrationHelper
    end
  end
  let(:helper) { helper_class.new }
  let(:account_id) { 123 }
  let(:client_secret) { 'test_secret_key' }

  before do
    create(:installation_config, name: 'GHL_CLIENT_SECRET', value: client_secret)
  end

  describe '#generate_ghl_token' do
    context 'when client secret is present' do
      it 'generates a valid JWT token' do
        token = helper.generate_ghl_token(account_id)

        expect(token).to be_present
        decoded = JWT.decode(token, client_secret, true, algorithm: 'HS256')
        expect(decoded.first['sub']).to eq(account_id)
      end

      it 'includes expiration in the token' do
        token = helper.generate_ghl_token(account_id)
        decoded = JWT.decode(token, client_secret, true, algorithm: 'HS256')

        expect(decoded.first['exp']).to be_present
        expect(decoded.first['exp']).to be > Time.current.to_i
      end
    end

    context 'when client secret is missing' do
      before do
        InstallationConfig.find_by(name: 'GHL_CLIENT_SECRET')&.destroy
      end

      it 'returns nil' do
        token = helper.generate_ghl_token(account_id)
        expect(token).to be_nil
      end
    end
  end

  describe '#verify_ghl_token' do
    context 'when token is valid' do
      it 'returns the account ID' do
        token = helper.generate_ghl_token(account_id)
        result = helper.verify_ghl_token(token)

        expect(result).to eq(account_id)
      end
    end

    context 'when token is expired' do
      it 'returns nil' do
        payload = {
          sub: account_id,
          iat: 1.hour.ago.to_i,
          exp: 30.minutes.ago.to_i
        }
        expired_token = JWT.encode(payload, client_secret, 'HS256')

        result = helper.verify_ghl_token(expired_token)
        expect(result).to be_nil
      end
    end

    context 'when token is invalid' do
      it 'returns nil' do
        result = helper.verify_ghl_token('invalid_token')
        expect(result).to be_nil
      end
    end

    context 'when token is blank' do
      it 'returns nil' do
        result = helper.verify_ghl_token('')
        expect(result).to be_nil
      end
    end

    context 'when client secret is missing' do
      before do
        InstallationConfig.find_by(name: 'GHL_CLIENT_SECRET')&.destroy
      end

      it 'returns nil' do
        # Generate token with a secret first
        token = JWT.encode({ sub: account_id }, 'some_secret', 'HS256')
        result = helper.verify_ghl_token(token)

        expect(result).to be_nil
      end
    end
  end
end
