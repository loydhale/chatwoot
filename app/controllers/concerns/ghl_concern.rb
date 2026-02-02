# frozen_string_literal: true

module GhlConcern
  extend ActiveSupport::Concern

  # GHL OAuth 2.0 Configuration
  # Docs: https://highlevel.stoplight.io/docs/integrations/authentication
  # Marketplace: https://marketplace.gohighlevel.com/apps
  GHL_OAUTH_BASE_URL = 'https://marketplace.gohighlevel.com'
  GHL_API_BASE_URL = 'https://services.leadconnectorhq.com'

  def ghl_client
    raise 'GHL OAuth credentials not configured (GHL_CLIENT_ID / GHL_CLIENT_SECRET)' if ghl_client_id.blank? || ghl_client_secret.blank?

    OAuth2::Client.new(
      ghl_client_id,
      ghl_client_secret,
      {
        site: GHL_API_BASE_URL,
        authorize_url: "#{GHL_OAUTH_BASE_URL}/oauth/chooselocation",
        token_url: '/oauth/token'
      }
    )
  end

  def ghl_configured?
    ghl_client_id.present? && ghl_client_secret.present?
  end

  private

  def ghl_client_id
    @ghl_client_id ||= GlobalConfigService.load('GHL_CLIENT_ID', nil)
  end

  def ghl_client_secret
    @ghl_client_secret ||= GlobalConfigService.load('GHL_CLIENT_SECRET', nil)
  end

  def ghl_scopes
    # Default scopes for DeskFlows integration
    # See docs/GHL-OAUTH.md for scope descriptions
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
