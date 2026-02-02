FactoryBot.define do
  factory :ghl_subscription do
    account
    plan { 'starter' }
    status { 'active' }
    locations_count { 1 }
    locations_limit { 5 }
    agents_limit { 3 }
    ai_credits_used { 0 }
    ai_credits_limit { 500 }
    trial_ends_at { 14.days.from_now }
    current_period_ends_at { 30.days.from_now }

    trait :trialing do
      status { 'trialing' }
    end

    trait :suspended do
      status { 'suspended' }
    end

    trait :cancelled do
      status { 'cancelled' }
      cancelled_at { Time.current }
    end

    trait :growth do
      plan { 'growth' }
      locations_limit { 5 }
      agents_limit { 10 }
      ai_credits_limit { 2_500 }
    end

    trait :scale do
      plan { 'scale' }
      locations_limit { 25 }
      agents_limit { 50 }
      ai_credits_limit { 10_000 }
    end
  end
end
