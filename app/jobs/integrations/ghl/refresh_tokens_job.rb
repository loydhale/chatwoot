# frozen_string_literal: true

class Integrations::Ghl::RefreshTokensJob < ApplicationJob
  queue_as :scheduled_jobs

  # Refresh tokens that expire within the next 6 hours.
  # The job is scheduled to run every 12 hours via sidekiq-cron,
  # giving two chances per day to catch expiring tokens.
  REFRESH_WINDOW = 6.hours

  def perform
    hooks = Integrations::Hook.where(app_id: 'gohighlevel', status: 'enabled')
    refreshed = 0
    failed = 0

    hooks.find_each do |hook|
      settings = hook.settings || {}
      refresh_token = settings['refresh_token']
      expires_at = parse_expires_at(settings['expires_at'])

      next if refresh_token.blank?

      # If we can't parse expires_at, refresh proactively
      next if expires_at.present? && expires_at > REFRESH_WINDOW.from_now

      new_tokens = Ghl::TokenRefreshService.new(refresh_token).refresh!

      hook.update!(
        access_token: new_tokens['access_token'],
        settings: settings.merge(
          refresh_token: new_tokens['refresh_token'] || refresh_token,
          expires_in: new_tokens['expires_in'],
          expires_at: (Time.current + new_tokens['expires_in'].to_i.seconds).iso8601,
          last_refreshed_at: Time.current.iso8601
        )
      )

      refreshed += 1
      Rails.logger.info("GHL token refresh succeeded for hook #{hook.id} (account #{hook.account_id})")
    rescue StandardError => e
      failed += 1
      Rails.logger.error("GHL token refresh FAILED for hook #{hook.id} (account #{hook.account_id}): #{e.message}")
      Rails.logger.error(e.backtrace&.first(3)&.join("\n"))
    end

    Rails.logger.info("GHL token refresh job complete: #{refreshed} refreshed, #{failed} failed, #{hooks.count} total")
  end

  private

  def parse_expires_at(value)
    return if value.blank?

    Time.zone.parse(value)
  rescue ArgumentError
    nil
  end
end
