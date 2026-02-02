# frozen_string_literal: true

module Ghl
  # Resets AI credit usage for all active GHL subscriptions.
  # Should be scheduled to run on the 1st of each month.
  #
  # Schedule in config/schedule.yml or via Sidekiq-cron:
  #   Ghl::MonthlyUsageResetJob.perform_later
  #
  class MonthlyUsageResetJob < ApplicationJob
    queue_as :low

    def perform
      reset_count = 0

      GhlSubscription.active.find_each do |sub|
        sub.reset_monthly_usage!
        reset_count += 1
      rescue StandardError => e
        Rails.logger.error("GHL usage reset failed for subscription #{sub.id}: #{e.message}")
      end

      Rails.logger.info("GHL monthly usage reset: #{reset_count} subscriptions reset")
    end
  end
end
