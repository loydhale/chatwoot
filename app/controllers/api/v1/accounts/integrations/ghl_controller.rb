# frozen_string_literal: true

class Api::V1::Accounts::Integrations::GhlController < Api::V1::Accounts::BaseController
  include Ghl::IntegrationHelper

  before_action :fetch_hook, except: [:status]
  before_action :check_authorization

  # GET /api/v1/accounts/:account_id/integrations/ghl/status
  def status
    hook = Current.account.hooks.find_by(app_id: 'gohighlevel')

    if hook.present?
      render json: {
        connected: true,
        location_id: hook.settings['location_id'],
        company_id: hook.settings['company_id'],
        connected_at: hook.settings['connected_at'],
        expires_at: hook.settings['expires_at']
      }
    else
      render json: { connected: false }
    end
  end

  # POST /api/v1/accounts/:account_id/integrations/ghl/refresh
  def refresh
    return render_token_refresh_not_supported unless @hook.settings['refresh_token'].present?

    new_tokens = refresh_access_token(@hook.settings['refresh_token'])

    @hook.update!(
      access_token: new_tokens['access_token'],
      settings: @hook.settings.merge(
        refresh_token: new_tokens['refresh_token'],
        expires_in: new_tokens['expires_in'],
        expires_at: (Time.current + new_tokens['expires_in'].to_i.seconds).iso8601
      )
    )

    render json: { success: true, message: 'Token refreshed successfully' }
  rescue StandardError => e
    Rails.logger.error("GHL token refresh error: #{e.message}")
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # DELETE /api/v1/accounts/:account_id/integrations/ghl
  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_hook
    @hook = Current.account.hooks.find_by!(app_id: 'gohighlevel')
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'GHL integration not found' }, status: :not_found
  end

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def refresh_access_token(refresh_token)
    client = OAuth2::Client.new(
      ghl_client_id,
      ghl_client_secret,
      site: 'https://services.leadconnectorhq.com',
      token_url: '/oauth/token'
    )

    token = OAuth2::AccessToken.from_hash(client, refresh_token: refresh_token)
    new_token = token.refresh!
    new_token.to_hash
  end

  def render_token_refresh_not_supported
    render json: { success: false, error: 'Refresh token not available' }, status: :unprocessable_entity
  end
end
