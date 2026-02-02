# frozen_string_literal: true

# == Schema Information
#
# Table name: ghl_subscriptions
#
#  id                      :bigint           not null, primary key
#  account_id              :bigint           not null
#  plan                    :string           not null, default: "starter"
#  status                  :string           not null, default: "trialing"
#  ghl_company_id          :string
#  ghl_location_id         :string
#  ghl_user_id             :string
#  ghl_app_id              :string
#  locations_count         :integer          default(1), not null
#  locations_limit         :integer          default(1), not null
#  agents_limit            :integer          default(3), not null
#  ai_credits_used         :integer          default(0), not null
#  ai_credits_limit        :integer          default(500), not null
#  usage_data              :jsonb            default({}), not null
#  metadata                :jsonb            default({}), not null
#  trial_ends_at           :datetime
#  current_period_ends_at  :datetime
#  cancelled_at            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class GhlSubscription < ApplicationRecord
  belongs_to :account

  # --- Plans ---
  PLANS = {
    'starter' => {
      name: 'Starter',
      locations_limit: 1,
      agents_limit: 3,
      ai_credits_limit: 500,
      price_monthly: 97,
      features: %w[live_chat email_inbox contact_sync basic_reporting]
    },
    'growth' => {
      name: 'Growth',
      locations_limit: 5,
      agents_limit: 10,
      ai_credits_limit: 2_500,
      price_monthly: 297,
      features: %w[live_chat email_inbox contact_sync advanced_reporting hudley_copilot automation_rules teams]
    },
    'scale' => {
      name: 'Scale',
      locations_limit: 25,
      agents_limit: 50,
      ai_credits_limit: 10_000,
      price_monthly: 697,
      features: %w[live_chat email_inbox contact_sync advanced_reporting hudley_copilot hudley_assistant
                   automation_rules teams white_label custom_domain api_access priority_support]
    },
    'enterprise' => {
      name: 'Enterprise',
      locations_limit: 999,
      agents_limit: 999,
      ai_credits_limit: 50_000,
      price_monthly: nil, # custom pricing
      features: %w[live_chat email_inbox contact_sync advanced_reporting hudley_copilot hudley_assistant
                   automation_rules teams white_label custom_domain api_access priority_support
                   dedicated_infrastructure sla_guarantee custom_integrations]
    }
  }.freeze

  STATUSES = %w[trialing active past_due cancelled suspended].freeze

  # --- Validations ---
  validates :plan, presence: true, inclusion: { in: PLANS.keys }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :locations_count, numericality: { greater_than_or_equal_to: 0 }
  validates :ai_credits_used, numericality: { greater_than_or_equal_to: 0 }

  # --- Scopes ---
  scope :active, -> { where(status: %w[trialing active]) }
  scope :by_plan, ->(plan) { where(plan: plan) }
  scope :expiring_soon, -> { where('current_period_ends_at <= ?', 3.days.from_now) }
  scope :over_ai_limit, -> { where('ai_credits_used >= ai_credits_limit') }

  # --- Plan Helpers ---

  def plan_config
    PLANS[plan]
  end

  def plan_name
    plan_config&.dig(:name) || plan.titleize
  end

  def features
    plan_config&.dig(:features) || []
  end

  def feature_enabled?(feature)
    features.include?(feature.to_s)
  end

  # --- Limit Checks ---

  def locations_available?
    locations_count < locations_limit
  end

  def agents_available?(current_count)
    current_count < agents_limit
  end

  def ai_credits_available?
    ai_credits_used < ai_credits_limit
  end

  def ai_credits_remaining
    [ai_credits_limit - ai_credits_used, 0].max
  end

  def ai_usage_percentage
    return 0 if ai_credits_limit.zero?

    ((ai_credits_used.to_f / ai_credits_limit) * 100).round(1)
  end

  def over_ai_limit?
    ai_credits_used >= ai_credits_limit
  end

  # --- Usage Tracking ---

  def increment_ai_usage!(credits = 1)
    increment!(:ai_credits_used, credits)

    # Track daily usage in usage_data
    today = Date.current.iso8601
    daily = usage_data['daily_ai'] || {}
    daily[today] = (daily[today] || 0) + credits
    update_column(:usage_data, usage_data.merge('daily_ai' => daily))
  end

  def reset_monthly_usage!
    update!(
      ai_credits_used: 0,
      usage_data: usage_data.merge(
        'last_reset' => Time.current.iso8601,
        'previous_month_ai_total' => ai_credits_used
      )
    )
  end

  # --- Plan Management ---

  def upgrade_to!(new_plan)
    config = PLANS[new_plan]
    raise ArgumentError, "Unknown plan: #{new_plan}" unless config

    update!(
      plan: new_plan,
      locations_limit: config[:locations_limit],
      agents_limit: config[:agents_limit],
      ai_credits_limit: config[:ai_credits_limit],
      status: 'active'
    )
  end

  def activate!
    update!(status: 'active')
  end

  def cancel!
    update!(
      status: 'cancelled',
      cancelled_at: Time.current
    )
  end

  def suspend!
    update!(status: 'suspended')
  end

  def trial_active?
    status == 'trialing' && trial_ends_at.present? && trial_ends_at > Time.current
  end

  def trial_days_remaining
    return 0 unless trial_active?

    ((trial_ends_at - Time.current) / 1.day).ceil
  end

  # --- Serialization ---

  def as_json_for_admin
    {
      id: id,
      account_id: account_id,
      account_name: account.name,
      plan: plan,
      plan_name: plan_name,
      status: status,
      ghl_company_id: ghl_company_id,
      ghl_location_id: ghl_location_id,
      locations_count: locations_count,
      locations_limit: locations_limit,
      agents_limit: agents_limit,
      ai_credits_used: ai_credits_used,
      ai_credits_limit: ai_credits_limit,
      ai_usage_percentage: ai_usage_percentage,
      features: features,
      trial_ends_at: trial_ends_at,
      trial_days_remaining: trial_days_remaining,
      current_period_ends_at: current_period_ends_at,
      cancelled_at: cancelled_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
