# frozen_string_literal: true

module Ghl::IntegrationHelper
  # Generates a signed JWT token for GHL integration
  #
  # @param account_id [Integer] The account ID to encode in the token
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_ghl_token(account_id)
    return if ghl_client_secret.blank?

    JWT.encode(ghl_token_payload(account_id), ghl_client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate GHL token: #{e.message}")
    nil
  end

  # Verifies and decodes a GHL JWT token
  #
  # @param token [String] The JWT token to verify
  # @return [Integer, nil] The account ID from the token or nil if invalid
  def verify_ghl_token(token)
    return if token.blank? || ghl_client_secret.blank?

    decode_ghl_token(token, ghl_client_secret)
  end

  private

  def ghl_token_payload(account_id)
    {
      sub: account_id,
      iat: Time.current.to_i,
      exp: 15.minutes.from_now.to_i
    }
  end

  def ghl_client_id
    @ghl_client_id ||= GlobalConfigService.load('GHL_CLIENT_ID', nil)
  end

  def ghl_client_secret
    @ghl_client_secret ||= GlobalConfigService.load('GHL_CLIENT_SECRET', nil)
  end

  def decode_ghl_token(token, secret)
    JWT.decode(
      token,
      secret,
      true,
      {
        algorithm: 'HS256',
        verify_expiration: true
      }
    ).first['sub']
  rescue JWT::ExpiredSignature => e
    Rails.logger.error("GHL token expired: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying GHL token: #{e.message}")
    nil
  end
end
