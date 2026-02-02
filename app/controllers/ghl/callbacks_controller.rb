# frozen_string_literal: true

class Ghl::CallbacksController < ApplicationController
  include GhlConcern
  include Ghl::IntegrationHelper

  def show
    verify_account!

    @response = ghl_client.auth_code.get_token(
      params[:code],
      redirect_uri: ghl_redirect_uri
    )

    handle_response
  rescue StandardError => e
    Rails.logger.error("GHL callback error: #{e.message}")
    redirect_to "#{ghl_integration_url}?error=true"
  end

  private

  def verify_account!
    @account_id = verify_ghl_token(params[:state])
    raise StandardError, 'Invalid state parameter' if account.blank?
  end

  def handle_response
    # Find or create the hook
    hook = account.hooks.find_or_initialize_by(app_id: 'gohighlevel')

    hook.update!(
      access_token: parsed_body['access_token'],
      status: 'enabled',
      reference_id: parsed_body['locationId'] || parsed_body['companyId'],
      settings: {
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
    )

    redirect_to ghl_integration_url
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
end
