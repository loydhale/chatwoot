# frozen_string_literal: true

# Super Admin controller for managing global GHL webhook configuration.
#
# Manages the system-wide webhook URL, signing secret, and event subscriptions.
# This is the master config — individual accounts inherit from here.
#
# Accessible at: /super_admin/ghl_webhook_settings
class SuperAdmin::GhlWebhookSettingsController < SuperAdmin::ApplicationController
  def show
    @webhook_url = build_webhook_url
    @webhook_secret = GlobalConfigService.load('GHL_WEBHOOK_SECRET', nil)
    @client_secret = GlobalConfigService.load('GHL_CLIENT_SECRET', nil)
    @client_id = GlobalConfigService.load('GHL_CLIENT_ID', nil)
    @active_hooks = Integrations::Hook.where(app_id: 'gohighlevel', status: 'enabled').count
    @total_hooks = Integrations::Hook.where(app_id: 'gohighlevel').count
    @recent_events = fetch_recent_events
  end

  def update
    if params[:webhook_secret].present?
      save_config('GHL_WEBHOOK_SECRET', params[:webhook_secret])
      flash[:notice] = 'Webhook secret updated successfully.'
    end

    if params[:regenerate_secret] == 'true'
      new_secret = SecureRandom.hex(32)
      save_config('GHL_WEBHOOK_SECRET', new_secret)
      flash[:notice] = "Webhook secret regenerated: #{new_secret[0..7]}..."
    end

    redirect_to super_admin_ghl_webhook_settings_path
  end

  private

  def build_webhook_url
    base = ENV.fetch('FRONTEND_URL', 'https://app.deskflows.ai')
    "#{base}/webhooks/ghl"
  end

  def save_config(name, value)
    config = InstallationConfig.find_or_initialize_by(name: name)
    config.value = value
    config.save!
  end

  def fetch_recent_events
    # Aggregate recent webhook activity from logs (last 24h)
    # In production, this would query a webhook_events table
    []
  end
end
