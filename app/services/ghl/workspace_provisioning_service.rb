# frozen_string_literal: true

# Automatically provisions a DeskFlows workspace when a GHL user installs the app.
#
# Called from:
#   1. Ghl::CallbacksController after OAuth token exchange
#   2. Webhooks::GhlController on app.installed event
#
# Creates:
#   - Account (workspace)
#   - Admin user (linked to GHL user)
#   - GHL subscription with trial
#   - Default API inbox for GHL messages
#   - GHL integration hook
#
class Ghl::WorkspaceProvisioningService
  TRIAL_DAYS = 14

  Result = Struct.new(:success?, :account, :user, :subscription, :hook, :error, keyword_init: true)

  attr_reader :oauth_data, :ghl_user_info

  # @param oauth_data [Hash] Token response from GHL OAuth
  # @param ghl_user_info [Hash] Optional user profile from GHL API
  def initialize(oauth_data:, ghl_user_info: {})
    @oauth_data = oauth_data.with_indifferent_access
    @ghl_user_info = ghl_user_info.with_indifferent_access
  end

  def perform
    result = nil

    ActiveRecord::Base.transaction do
      # Check for existing workspace first
      existing = find_existing_workspace
      if existing
        reconnect_existing(existing)
        result = Result.new(
          'success?': true,
          account: existing,
          user: existing.administrators.first,
          subscription: existing.ghl_subscription,
          hook: existing.hooks.find_by(app_id: 'gohighlevel'),
          error: nil
        )
      else
        account = create_account
        user = create_admin_user(account)
        subscription = create_subscription(account)
        hook = create_integration_hook(account)
        inbox = create_default_inbox(account)
        configure_account_defaults(account, inbox)

        Rails.logger.info(
          "GHL provisioning: created workspace account=#{account.id} " \
          "location=#{location_id} company=#{company_id} user=#{user.id}"
        )

        result = Result.new(
          'success?': true,
          account: account,
          user: user,
          subscription: subscription,
          hook: hook,
          error: nil
        )
      end
    end

    result
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error("GHL provisioning failed: #{e.message}")
    Result.new('success?': false, error: e.message)
  rescue StandardError => e
    Rails.logger.error("GHL provisioning unexpected error: #{e.class} — #{e.message}")
    Result.new('success?': false, error: e.message)
  end

  private

  # --- Account ---

  def create_account
    Account.create!(
      name: workspace_name,
      ghl_location_id: location_id,
      ghl_company_id: company_id,
      locale: :en,
      custom_attributes: {
        'ghl_provisioned' => true,
        'ghl_provisioned_at' => Time.current.iso8601,
        'ghl_user_type' => oauth_data['userType']
      }
    )
  end

  # --- Admin User ---

  def create_admin_user(account)
    email = derive_email
    user = User.find_by(email: email)

    if user
      # Existing user — just add to this account as admin
      link_user_to_account(user, account)
      return user
    end

    user = User.create!(
      email: email,
      name: derive_name,
      password: generate_secure_password,
      confirmed_at: Time.current,
      custom_attributes: {
        'ghl_user_id' => ghl_user_id,
        'ghl_provisioned' => true
      }
    )

    link_user_to_account(user, account)
    user
  end

  def link_user_to_account(user, account)
    AccountUser.create!(
      account: account,
      user: user,
      role: :administrator
    )
  end

  # --- Subscription ---

  def create_subscription(account)
    GhlSubscription.create!(
      account: account,
      plan: 'starter',
      status: 'trialing',
      ghl_company_id: company_id,
      ghl_location_id: location_id,
      ghl_user_id: ghl_user_id,
      ghl_app_id: oauth_data['appId'],
      trial_ends_at: TRIAL_DAYS.days.from_now,
      current_period_ends_at: TRIAL_DAYS.days.from_now,
      metadata: {
        'oauth_scopes' => oauth_data['scope'],
        'provisioned_at' => Time.current.iso8601
      }
    )
  end

  # --- Integration Hook ---

  def create_integration_hook(account)
    hook = account.hooks.find_or_initialize_by(app_id: 'gohighlevel')

    hook.update!(
      access_token: oauth_data['access_token'],
      refresh_token: oauth_data['refresh_token'],
      status: 'enabled',
      reference_id: location_id || company_id,
      settings: {
        token_type: oauth_data['token_type'],
        expires_in: oauth_data['expires_in'],
        # refresh_token now stored in encrypted column — not in settings JSON
        scope: oauth_data['scope'],
        user_type: oauth_data['userType'],
        location_id: location_id,
        company_id: company_id,
        user_id: ghl_user_id,
        connected_at: Time.current.iso8601,
        expires_at: (Time.current + oauth_data['expires_in'].to_i.seconds).iso8601
      }
    )

    hook
  end

  # --- Default Inbox ---

  def create_default_inbox(account)
    channel = Channel::Api.create!(account: account)

    Inbox.create!(
      account: account,
      name: 'GHL Messages',
      channel: channel,
      greeting_enabled: true,
      greeting_message: "Welcome! We'll get back to you shortly."
    )
  end

  # --- Account Configuration ---

  def configure_account_defaults(account, _inbox)
    # Enable useful features by default
    account.update!(
      settings: (account.settings || {}).merge(
        'auto_resolve_after' => 4320,  # 3 days
        'auto_resolve_message' => 'This conversation was automatically resolved due to inactivity. Feel free to reach out again!'
      )
    )
  end

  # --- Reconnection (re-install) ---

  def find_existing_workspace
    return Account.find_by(ghl_location_id: location_id) if location_id.present?
    return Account.find_by(ghl_company_id: company_id) if company_id.present?

    nil
  end

  def reconnect_existing(account)
    # Re-establish the hook with fresh tokens
    create_integration_hook(account)

    # Reactivate subscription if cancelled
    sub = account.ghl_subscription
    sub&.activate! if sub&.status == 'cancelled'

    # Update GHL IDs if they changed
    account.update!(
      ghl_location_id: location_id || account.ghl_location_id,
      ghl_company_id: company_id || account.ghl_company_id
    )

    Rails.logger.info("GHL provisioning: reconnected existing workspace account=#{account.id}")
  end

  # --- Data Extraction ---

  def location_id
    oauth_data['locationId']
  end

  def company_id
    oauth_data['companyId']
  end

  def ghl_user_id
    oauth_data['userId']
  end

  # Generate a password that satisfies devise-secure_password rules:
  # at least 1 uppercase, 1 lowercase, 1 digit, and 1 special character
  def generate_secure_password
    base = SecureRandom.alphanumeric(20)
    "#{base}!A1z"
  end

  def derive_email
    ghl_user_info['email'].presence ||
      "ghl-#{ghl_user_id || SecureRandom.hex(6)}@deskflows.ai"
  end

  def derive_name
    ghl_user_info['name'].presence ||
      (ghl_user_info['firstName'].present? && "#{ghl_user_info['firstName']} #{ghl_user_info['lastName']}".strip.presence) ||
      'GHL User'
  end

  def workspace_name
    ghl_user_info['companyName'].presence ||
      ghl_user_info['locationName'].presence ||
      'DeskFlows Workspace'
  end
end
