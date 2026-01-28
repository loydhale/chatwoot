# frozen_string_literal: true

module GhlConcern
  extend ActiveSupport::Concern

  # GHL OAuth 2.0 Configuration
  # Documentation: https://marketplace.gohighlevel.com/docs/oauth/Overview
  GHL_OAUTH_BASE_URL = 'https://marketplace.gohighlevel.com'
  GHL_API_BASE_URL = 'https://services.leadconnectorhq.com'

  def ghl_client
    app_id = GlobalConfigService.load('GHL_CLIENT_ID', nil)
    app_secret = GlobalConfigService.load('GHL_CLIENT_SECRET', nil)

    OAuth2::Client.new(
      app_id,
      app_secret,
      {
        site: GHL_API_BASE_URL,
        authorize_url: "#{GHL_OAUTH_BASE_URL}/oauth/chooselocation",
        token_url: '/oauth/token'
      }
    )
  end

  private

  def ghl_scopes
    # Default scopes for DeskFlow integration
    # Adjust based on features needed
    [
      'contacts.readonly',
      'contacts.write',
      'conversations.readonly',
      'conversations.write',
      'conversations/message.readonly',
      'conversations/message.write',
      'locations.readonly',
      'users.readonly'
    ].join(' ')
  end
end
