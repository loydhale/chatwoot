# frozen_string_literal: true

# GHL OAuth 2.0 Callback Controller
#
# Handles the redirect back from GoHighLevel after the user authorizes DeskFlow.
# Flow: GHL → GET /ghl/callback?code=xxx&state=jwt → exchange code → store tokens
#
# See docs/GHL-OAUTH.md for the full OAuth flow.
class Ghl::CallbacksController < ApplicationController
  include GhlConcern
  include Ghl::IntegrationHelper

  skip_before_action :verify_authenticity_token, only: [:show]

  def show
    return redirect_to_error('missing_params') if params[:code].blank? || params[:state].blank?

    verify_account!

    @response = ghl_client.auth_code.get_token(
      params[:code],
      redirect_uri: ghl_redirect_uri
    )

    handle_response
  rescue OAuth2::Error => e
    Rails.logger.error("GHL OAuth token exchange failed: #{e.message} — #{e.response&.body}")
    redirect_to_error('token_exchange_failed')
  rescue StandardError => e
    Rails.logger.error("GHL callback error: #{e.class} — #{e.message}")
    redirect_to_error('unknown')
  end

  private

  def verify_account!
    @account_id = verify_ghl_token(params[:state])
    raise StandardError, 'Invalid or expired state token' if account.blank?
  end

  def handle_response
    hook = account.hooks.find_or_initialize_by(app_id: 'gohighlevel')

    hook.update!(
      access_token: parsed_body['access_token'],
      status: 'enabled',
      reference_id: parsed_body['locationId'] || parsed_body['companyId'],
      settings: build_hook_settings
    )

    Rails.logger.info(
      "GHL OAuth connected: account=#{account.id} location=#{parsed_body['locationId']} hook=#{hook.id}"
    )

    redirect_to ghl_integration_url, allow_other_host: true
  end

  def build_hook_settings
    {
      token_type: parsed_body['token_type'],
      expires_in: parsed_body['expires_in'],
      refresh_token: parsed_body['refresh_token'],
      scope: parsed_body['scope'],
      user_type: parsed_body['userType'],
      location_id: parsed_body['locationId'],
      company_id: parsed_body['companyId'],
      user_id: parsed_body['userId'],
      connected_at: Time.current.iso8601,
      expires_at: (Time.current + parsed_body['expires_in'].to_i.seconds).iso8601
    }
  end

  def parsed_body
    @parsed_body ||= @response.response.parsed
  end

  def account
    @account ||= Account.find_by(id: @account_id)
  end

  def ghl_redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/ghl/callback"
  end

  def ghl_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{account.id}/settings/integrations/gohighlevel"
  end

  def redirect_to_error(reason)
    base_url = ENV.fetch('FRONTEND_URL', '')
    redirect_to "#{base_url}/app/settings/integrations/gohighlevel?error=#{reason}", allow_other_host: true
  end
end
