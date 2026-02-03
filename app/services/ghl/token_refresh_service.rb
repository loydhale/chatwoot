# frozen_string_literal: true

class Ghl::TokenRefreshService
  def initialize(refresh_token)
    @refresh_token = refresh_token
  end

  def refresh!
    token.refresh!.to_hash
  end

  private

  attr_reader :refresh_token

  def token
    OAuth2::AccessToken.from_hash(oauth_client, refresh_token: refresh_token)
  end

  def oauth_client
    OAuth2::Client.new(
      ghl_client_id,
      ghl_client_secret,
      site: 'https://services.leadconnectorhq.com',
      token_url: '/oauth/token'
    )
  end

  def ghl_client_id
    GlobalConfigService.load('GHL_CLIENT_ID', nil)
  end

  def ghl_client_secret
    GlobalConfigService.load('GHL_CLIENT_SECRET', nil)
  end
end
