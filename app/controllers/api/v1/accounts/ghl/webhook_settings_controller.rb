# frozen_string_literal: true

# Manages GHL webhook configuration for an account.
#
# Allows admins to view the webhook URL, regenerate the secret,
# and see webhook delivery status.
#
# GET  /api/v1/accounts/:account_id/ghl/webhook_settings
# POST /api/v1/accounts/:account_id/ghl/webhook_settings
# PUT  /api/v1/accounts/:account_id/ghl/webhook_settings
#
class Api::V1::Accounts::Ghl::WebhookSettingsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  # GET — show current webhook configuration
  def show
    hook = Current.account.hooks.find_by(app_id: 'gohighlevel')

    webhook_url = build_webhook_url
    webhook_secret = GlobalConfigService.load('GHL_WEBHOOK_SECRET', nil)
    account_settings = Current.account.custom_attributes || {}

    render json: {
      webhook_url: webhook_url,
      webhook_secret_configured: webhook_secret.present?,
      webhook_secret_preview: webhook_secret.present? ? "#{webhook_secret[0..5]}...#{webhook_secret[-4..]}" : nil,
      ghl_connected: hook.present?,
      ghl_location_id: hook&.reference_id,
      events_enabled: account_settings['ghl_webhook_events'] || default_events,
      last_webhook_received_at: account_settings['ghl_last_webhook_at'],
      webhook_stats: account_settings['ghl_webhook_stats'] || {}
    }
  end

  # POST — update webhook settings (events to subscribe to)
  def create
    account_settings = Current.account.custom_attributes || {}

    if params[:events].present?
      allowed = params[:events].select { |e| valid_event?(e) }
      account_settings['ghl_webhook_events'] = allowed
    end

    Current.account.update!(custom_attributes: account_settings)

    render json: {
      success: true,
      webhook_url: build_webhook_url,
      events_enabled: account_settings['ghl_webhook_events'] || default_events
    }
  end

  # PUT — regenerate webhook secret
  def update
    new_secret = SecureRandom.hex(32)

    # Store via GlobalConfig (super_admin level)
    config = InstallationConfig.find_or_initialize_by(name: 'GHL_WEBHOOK_SECRET')
    config.value = new_secret
    config.save!

    render json: {
      success: true,
      webhook_secret: new_secret,
      message: 'Webhook secret regenerated. Update this in your GHL app settings.'
    }
  end

  private

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def build_webhook_url
    base = ENV.fetch('FRONTEND_URL', request.base_url)
    "#{base}/webhooks/ghl"
  end

  def default_events
    %w[
      contact.create contact.update contact.delete
      conversation.message conversation.status
      opportunity.create opportunity.update opportunity.delete opportunity.status_change
      app.installed app.uninstalled
    ]
  end

  def valid_event?(event)
    default_events.include?(event) ||
      %w[location.create location.update].include?(event)
  end
end
