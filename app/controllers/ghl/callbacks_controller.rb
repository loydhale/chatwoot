# frozen_string_literal: true

# GHL OAuth 2.0 Callback Controller
#
# Handles TWO flows:
#   1. Existing account connecting GHL (has state JWT with account_id)
#   2. New marketplace install (no existing account → auto-provision workspace)
#
# Flow: GHL → GET /ghl/callback?code=xxx&state=jwt → exchange code → store tokens
#
# See docs/GHL-OAUTH.md for the full OAuth flow.
class Ghl::CallbacksController < ApplicationController
  include GhlConcern
  include Ghl::IntegrationHelper

  # verify_authenticity_token is already skipped globally in ApplicationController

  def show
    return redirect_to_error('missing_params') if params[:code].blank?

    # Validate state BEFORE exchanging the OAuth code (CSRF protection)
    if params[:state].present?
      @account_id = verify_ghl_token(params[:state])
      return redirect_to_error('invalid_state') if @account_id.blank?
    else
      # Marketplace installs: GHL initiates these without a DeskFlows-signed state.
      # Verify we have the minimum required params to prove GHL origin.
      unless params[:code].present? && ghl_configured?
        return redirect_to_error('missing_state')
      end
    end

    @response = ghl_client.auth_code.get_token(
      params[:code],
      redirect_uri: ghl_redirect_uri
    )

    if params[:state].present?
      handle_existing_account
    else
      handle_marketplace_install
    end
  rescue OAuth2::Error => e
    Rails.logger.error("GHL OAuth token exchange failed: #{e.message} — #{e.response&.body}")
    redirect_to_error('token_exchange_failed')
  rescue StandardError => e
    Rails.logger.error("GHL callback error: #{e.class} — #{e.message}")
    redirect_to_error('unknown')
  end

  private

  # --- Flow 1: Existing account connecting GHL ---

  def handle_existing_account
    # @account_id already validated in #show before token exchange
    raise StandardError, 'Invalid or expired state token' if account.blank?

    hook = account.hooks.find_or_initialize_by(app_id: 'gohighlevel')
    hook.update!(
      access_token: parsed_body['access_token'],
      refresh_token: parsed_body['refresh_token'],
      status: 'enabled',
      reference_id: parsed_body['locationId'] || parsed_body['companyId'],
      settings: build_hook_settings
    )

    # Update GHL IDs on the account
    account.update!(
      ghl_location_id: parsed_body['locationId'] || account.ghl_location_id,
      ghl_company_id: parsed_body['companyId'] || account.ghl_company_id
    )

    # Ensure subscription exists
    ensure_subscription_exists(account)

    Rails.logger.info(
      "GHL OAuth connected: account=#{account.id} location=#{parsed_body['locationId']} hook=#{hook.id}"
    )

    redirect_to ghl_integration_url, allow_other_host: true
  end

  # --- Flow 2: New marketplace install (auto-provision) ---

  def handle_marketplace_install
    result = Ghl::WorkspaceProvisioningService.new(
      oauth_data: parsed_body,
      ghl_user_info: fetch_ghl_user_info
    ).perform

    unless result.success?
      Rails.logger.error("GHL marketplace install failed: #{result.error}")
      return redirect_to_error('provisioning_failed')
    end

    @account_id = result.account.id

    Rails.logger.info(
      "GHL marketplace install: provisioned account=#{result.account.id} " \
      "location=#{parsed_body['locationId']}"
    )

    redirect_to ghl_integration_url, allow_other_host: true
  end

  # --- Shared ---

  def ensure_subscription_exists(acct)
    return if acct.ghl_subscription.present?

    GhlSubscription.create!(
      account: acct,
      plan: 'starter',
      status: 'trialing',
      ghl_company_id: parsed_body['companyId'],
      ghl_location_id: parsed_body['locationId'],
      ghl_user_id: parsed_body['userId'],
      trial_ends_at: 14.days.from_now,
      current_period_ends_at: 14.days.from_now
    )
  end

  def fetch_ghl_user_info
    return {} if parsed_body['access_token'].blank?

    # Try to fetch user/location info from GHL API for better naming
    uri = URI("https://services.leadconnectorhq.com/locations/#{parsed_body['locationId']}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{parsed_body['access_token']}"
    req['Version'] = '2021-07-28'

    response = http.request(req)
    return {} unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    location = data['location'] || data
    {
      'companyName' => location['name'] || location['companyName'],
      'locationName' => location['name'],
      'email' => location['email'],
      'name' => location['name']
    }
  rescue StandardError => e
    Rails.logger.warn("GHL user info fetch failed (non-fatal): #{e.message}")
    {}
  end

  def build_hook_settings
    {
      token_type: parsed_body['token_type'],
      expires_in: parsed_body['expires_in'],
      # refresh_token now stored in encrypted column — not in settings JSON
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
