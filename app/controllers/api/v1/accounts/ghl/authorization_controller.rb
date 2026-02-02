# frozen_string_literal: true

# Initiates the GHL OAuth flow by generating an authorization URL.
#
# POST /api/v1/accounts/:account_id/ghl/authorization
#
# Returns { success: true, url: "https://marketplace.gohighlevel.com/oauth/..." }
# The frontend redirects the user to this URL. GHL sends them back to GET /ghl/callback.
#
# See docs/GHL-OAUTH.md for the full OAuth flow.
class Api::V1::Accounts::Ghl::AuthorizationController < Api::V1::Accounts::BaseController
  include GhlConcern
  include Ghl::IntegrationHelper

  before_action :check_authorization

  def create
    return render_missing_credentials unless ghl_configured?

    state = generate_ghl_token(Current.account.id)
    return render_state_error if state.blank?

    redirect_url = ghl_client.auth_code.authorize_url(
      redirect_uri: ghl_redirect_uri,
      scope: ghl_scopes,
      response_type: 'code',
      state: state
    )

    render json: { success: true, url: redirect_url }
  rescue StandardError => e
    Rails.logger.error("GHL authorization initiation failed: #{e.message}")
    render json: { success: false, error: 'Failed to generate authorization URL' }, status: :unprocessable_entity
  end

  private

  def ghl_redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/ghl/callback"
  end

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def render_missing_credentials
    render json: {
      success: false,
      error: 'GHL OAuth credentials not configured. Set GHL_CLIENT_ID and GHL_CLIENT_SECRET.'
    }, status: :unprocessable_entity
  end

  def render_state_error
    render json: {
      success: false,
      error: 'Failed to generate state token. Check GHL_CLIENT_SECRET configuration.'
    }, status: :unprocessable_entity
  end
end
