# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GhlSubscription, type: :model do
  subject(:subscription) do
    described_class.create!(
      account: account,
      plan: 'starter',
      status: 'trialing',
      trial_ends_at: 14.days.from_now,
      current_period_ends_at: 14.days.from_now
    )
  end

  let(:account) { create(:account) }

  describe 'validations' do
    it { is_expected.to be_valid }

    it 'requires a valid plan' do
      subscription.plan = 'invalid_plan'
      expect(subscription).not_to be_valid
    end

    it 'requires a valid status' do
      subscription.status = 'bogus'
      expect(subscription).not_to be_valid
    end
  end

  describe 'plan configuration' do
    it 'returns plan config' do
      expect(subscription.plan_config).to be_a(Hash)
      expect(subscription.plan_config[:name]).to eq('Starter')
    end

    it 'returns features for the plan' do
      expect(subscription.features).to include('live_chat', 'contact_sync')
    end

    it 'checks feature availability' do
      expect(subscription.feature_enabled?(:live_chat)).to be true
      expect(subscription.feature_enabled?(:white_label)).to be false
    end
  end

  describe 'limit checks' do
    it 'checks agent availability' do
      expect(subscription.agents_available?(2)).to be true
      expect(subscription.agents_available?(3)).to be false
    end

    it 'checks AI credits' do
      expect(subscription.ai_credits_available?).to be true
      subscription.update!(ai_credits_used: 500)
      expect(subscription.ai_credits_available?).to be false
    end

    it 'calculates AI usage percentage' do
      subscription.update!(ai_credits_used: 250)
      expect(subscription.ai_usage_percentage).to eq(50.0)
    end
  end

  describe '#increment_ai_usage!' do
    it 'increments credits' do
      subscription.increment_ai_usage!(10)
      expect(subscription.reload.ai_credits_used).to eq(10)
    end

    it 'tracks daily usage' do
      subscription.increment_ai_usage!(5)
      today = Date.current.iso8601
      expect(subscription.reload.usage_data.dig('daily_ai', today)).to eq(5)
    end
  end

  describe '#upgrade_to!' do
    it 'upgrades the plan' do
      subscription.upgrade_to!('growth')
      expect(subscription.plan).to eq('growth')
      expect(subscription.locations_limit).to eq(5)
      expect(subscription.agents_limit).to eq(10)
      expect(subscription.ai_credits_limit).to eq(2500)
    end

    it 'rejects unknown plans' do
      expect { subscription.upgrade_to!('platinum') }.to raise_error(ArgumentError)
    end
  end

  describe 'trial' do
    it 'detects active trial' do
      expect(subscription.trial_active?).to be true
    end

    it 'calculates remaining days' do
      expect(subscription.trial_days_remaining).to eq(14)
    end

    it 'detects expired trial' do
      subscription.update!(trial_ends_at: 1.day.ago)
      expect(subscription.trial_active?).to be false
    end
  end
end
