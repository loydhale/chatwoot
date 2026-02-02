# frozen_string_literal: true

# Concern for enforcing GHL subscription plan limits.
# Include in controllers/services that need to check plan limits.
#
# Usage:
#   include GhlPlanEnforcement
#
#   def some_action
#     enforce_agent_limit!(account)
#     enforce_ai_credits!(account)
#     # ... proceed
#   end
#
module GhlPlanEnforcement
  extend ActiveSupport::Concern

  class PlanLimitExceeded < StandardError
    attr_reader :limit_type, :current, :maximum

    def initialize(limit_type:, current:, maximum:)
      @limit_type = limit_type
      @current = current
      @maximum = maximum
      super("#{limit_type.to_s.titleize} limit exceeded: #{current}/#{maximum}")
    end
  end

  # Check if account can add more agents
  def enforce_agent_limit!(account)
    sub = account.ghl_subscription
    return true unless sub # No subscription = no limits (legacy accounts)

    current_agents = account.account_users.count
    return true if sub.agents_available?(current_agents)

    raise PlanLimitExceeded.new(
      limit_type: :agents,
      current: current_agents,
      maximum: sub.agents_limit
    )
  end

  # Check if account can add more locations
  def enforce_location_limit!(account)
    sub = account.ghl_subscription
    return true unless sub

    return true if sub.locations_available?

    raise PlanLimitExceeded.new(
      limit_type: :locations,
      current: sub.locations_count,
      maximum: sub.locations_limit
    )
  end

  # Check if account has AI credits remaining
  def enforce_ai_credits!(account, credits_needed = 1)
    sub = account.ghl_subscription
    return true unless sub

    return true if sub.ai_credits_remaining >= credits_needed

    raise PlanLimitExceeded.new(
      limit_type: :ai_credits,
      current: sub.ai_credits_used,
      maximum: sub.ai_credits_limit
    )
  end

  # Check if a specific feature is available on the plan
  def enforce_feature!(account, feature)
    sub = account.ghl_subscription
    return true unless sub

    return true if sub.feature_enabled?(feature)

    raise PlanLimitExceeded.new(
      limit_type: "feature_#{feature}",
      current: 0,
      maximum: 0
    )
  end

  # Soft check (returns boolean instead of raising)
  def plan_allows?(account, check_type, *args)
    case check_type
    when :agents
      sub = account.ghl_subscription
      sub.nil? || sub.agents_available?(args[0] || account.account_users.count)
    when :locations
      sub = account.ghl_subscription
      sub.nil? || sub.locations_available?
    when :ai_credits
      sub = account.ghl_subscription
      sub.nil? || sub.ai_credits_available?
    when :feature
      sub = account.ghl_subscription
      sub.nil? || sub.feature_enabled?(args[0])
    else
      true
    end
  end
end
