# frozen_string_literal: true

class Api::V1::Accounts::Integrations::GhlController < Api::V1::Accounts::BaseController

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
    settings = @hook.settings || {}
    refresh_token = settings['refresh_token']
    return render_token_refresh_not_supported unless refresh_token.present?

    new_tokens = Ghl::TokenRefreshService.new(refresh_token).refresh!

    @hook.update!(
      access_token: new_tokens['access_token'],
      settings: settings.merge(
        refresh_token: new_tokens['refresh_token'] || refresh_token,
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

  def render_token_refresh_not_supported
    render json: { success: false, error: 'Refresh token not available' }, status: :unprocessable_entity
  end
end
