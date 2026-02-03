# frozen_string_literal: true

# Hourly job to proactively refresh GHL OAuth tokens before they expire.
#
# Finds all enabled GHL hooks whose access tokens expire within the next 2 hours
# and refreshes them via the OAuth2 token endpoint. This provides tighter coverage
# than the existing Integrations::Ghl::RefreshTokensJob (12h / 6h window).
#
# Scheduled via sidekiq-cron in config/schedule.yml.
class Ghl::TokenRefreshJob < ApplicationJob
  queue_as :scheduled_jobs

  # Refresh tokens expiring within 2 hours
  REFRESH_WINDOW = 2.hours

  def perform
    hooks = expiring_hooks
    refreshed = 0
    failed = 0

    hooks.find_each do |hook|
      refresh_hook(hook)
      refreshed += 1
    rescue StandardError => e
      failed += 1
      Rails.logger.error(
        "[GHL::TokenRefreshJob] FAILED hook=#{hook.id} account=#{hook.account_id}: #{e.message}"
      )
      Rails.logger.error(e.backtrace&.first(3)&.join("\n"))
    end

    Rails.logger.info(
      "[GHL::TokenRefreshJob] complete: refreshed=#{refreshed} failed=#{failed} candidates=#{hooks.count}"
    )
  end

  private

  # Returns enabled GHL hooks whose token expires within the refresh window,
  # or whose expires_at is missing (proactive refresh).
  def expiring_hooks
    Integrations::Hook
      .where(app_id: 'gohighlevel', status: 'enabled')
      .where.not(settings: nil)
      .select { |hook| needs_refresh?(hook) }
      .then { |hooks| Integrations::Hook.where(id: hooks.map(&:id)) }
  end

  def needs_refresh?(hook)
    settings = hook.settings || {}
    refresh_token = settings['refresh_token']
    return false if refresh_token.blank?

    expires_at = parse_expires_at(settings['expires_at'])

    # If expires_at is missing or unparseable, refresh proactively
    return true if expires_at.nil?

    # Refresh if token expires within the window
    expires_at <= REFRESH_WINDOW.from_now
  end

  def refresh_hook(hook)
    settings = hook.settings || {}
    refresh_token = settings['refresh_token']

    new_tokens = Ghl::TokenRefreshService.new(refresh_token).refresh!

    hook.update!(
      access_token: new_tokens['access_token'],
      settings: settings.merge(
        'refresh_token' => new_tokens['refresh_token'] || refresh_token,
        'expires_in' => new_tokens['expires_in'],
        'expires_at' => (Time.current + new_tokens['expires_in'].to_i.seconds).iso8601,
        'last_refreshed_at' => Time.current.iso8601
      )
    )

    Rails.logger.info(
      "[GHL::TokenRefreshJob] refreshed hook=#{hook.id} account=#{hook.account_id}"
    )
  end

  def parse_expires_at(value)
    return nil if value.blank?

    Time.zone.parse(value)
  rescue ArgumentError
    nil
  end
end
