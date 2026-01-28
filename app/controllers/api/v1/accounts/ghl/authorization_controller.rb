# frozen_string_literal: true

class Api::V1::Accounts::Ghl::AuthorizationController < Api::V1::Accounts::BaseController
  include GhlConcern
  include Ghl::IntegrationHelper

  before_action :check_authorization

  def create
    return render_missing_credentials if ghl_client_id.blank? || ghl_client_secret.blank?

    state = generate_ghl_token(Current.account.id)

    redirect_url = ghl_client.auth_code.authorize_url(
      redirect_uri: ghl_redirect_uri,
      scope: ghl_scopes,
      response_type: 'code',
      state: state
    )

    if redirect_url
      render json: { success: true, url: redirect_url }
    else
      render json: { success: false, error: 'Failed to generate authorization URL' }, status: :unprocessable_entity
    end
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
      error: 'GHL OAuth credentials not configured. Please contact your administrator.'
    }, status: :unprocessable_entity
  end
end
