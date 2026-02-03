# frozen_string_literal: true

# API endpoint for GHL subscription management.
# Used by the Vue frontend settings page.
#
# GET    /api/v1/accounts/:account_id/ghl/subscription
# PATCH  /api/v1/accounts/:account_id/ghl/subscription
class Api::V1::Accounts::Ghl::SubscriptionsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    subscription = Current.account.ghl_subscription

    unless subscription
      render json: { error: 'No GHL subscription found', has_subscription: false }, status: :ok
      return
    end

    render json: {
      has_subscription: true,
      subscription: subscription_json(subscription),
      plans: GhlSubscription::PLANS.transform_values { |v| v.except(:features) },
      available_plans: available_upgrades(subscription)
    }
  end

  def usage
    subscription = Current.account.ghl_subscription
    return render json: { error: 'No subscription' }, status: :not_found unless subscription

    render json: {
      ai_credits_used: subscription.ai_credits_used,
      ai_credits_limit: subscription.ai_credits_limit,
      ai_usage_percentage: subscription.ai_usage_percentage,
      ai_credits_remaining: subscription.ai_credits_remaining,
      locations_count: subscription.locations_count,
      locations_limit: subscription.locations_limit,
      agents_count: Current.account.account_users.count,
      agents_limit: subscription.agents_limit,
      daily_usage: subscription.usage_data['daily_ai'] || {},
      plan: subscription.plan,
      status: subscription.status,
      trial_days_remaining: subscription.trial_days_remaining,
      current_period_ends_at: subscription.current_period_ends_at
    }
  end

  private

  def check_authorization
    authorize :account, :administrator?
  end

  def subscription_json(sub)
    {
      id: sub.id,
      plan: sub.plan,
      plan_name: sub.plan_name,
      status: sub.status,
      features: sub.features,
      locations_count: sub.locations_count,
      locations_limit: sub.locations_limit,
      agents_limit: sub.agents_limit,
      ai_credits_used: sub.ai_credits_used,
      ai_credits_limit: sub.ai_credits_limit,
      ai_usage_percentage: sub.ai_usage_percentage,
      trial_active: sub.trial_active?,
      trial_days_remaining: sub.trial_days_remaining,
      trial_ends_at: sub.trial_ends_at,
      current_period_ends_at: sub.current_period_ends_at,
      created_at: sub.created_at
    }
  end

  def available_upgrades(subscription)
    current_index = GhlSubscription::PLANS.keys.index(subscription.plan) || 0
    GhlSubscription::PLANS.keys[current_index + 1..] || []
  end
end
