# frozen_string_literal: true

require 'administrate/base_dashboard'

class GhlSubscriptionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    account: Field::BelongsTo,
    plan: Field::String,
    status: Field::String,
    ghl_company_id: Field::String,
    ghl_location_id: Field::String,
    ghl_user_id: Field::String,
    locations_count: Field::Number,
    locations_limit: Field::Number,
    agents_limit: Field::Number,
    ai_credits_used: Field::Number,
    ai_credits_limit: Field::Number,
    trial_ends_at: Field::DateTime,
    current_period_ends_at: Field::DateTime,
    cancelled_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    account
    plan
    status
    ai_credits_used
    locations_count
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    account
    plan
    status
    ghl_company_id
    ghl_location_id
    ghl_user_id
    locations_count
    locations_limit
    agents_limit
    ai_credits_used
    ai_credits_limit
    trial_ends_at
    current_period_ends_at
    cancelled_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    plan
    status
    locations_limit
    agents_limit
    ai_credits_limit
    trial_ends_at
    current_period_ends_at
  ].freeze

  def display_resource(subscription)
    "#{subscription.account&.name} (#{subscription.plan})"
  end
end
