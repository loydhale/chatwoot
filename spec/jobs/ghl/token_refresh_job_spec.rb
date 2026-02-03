# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ghl::TokenRefreshJob do
  subject(:job) { described_class.new }

  let(:account) { create(:account) }

  let(:token_response) do
    {
      'access_token' => 'new_access_token',
      'refresh_token' => 'new_refresh_token',
      'expires_in' => 86_400
    }
  end

  let(:refresh_service) { instance_double(Ghl::TokenRefreshService) }

  before do
    allow(Ghl::TokenRefreshService).to receive(:new).and_return(refresh_service)
    allow(refresh_service).to receive(:refresh!).and_return(token_response)
  end

  it 'enqueues on scheduled_jobs queue' do
    expect {
      described_class.perform_later
    }.to have_enqueued_job(described_class).on_queue('scheduled_jobs')
  end

  context 'when there are no GHL hooks' do
    it 'completes without error' do
      expect { job.perform }.not_to raise_error
    end
  end

  context 'when a hook has a token expiring within 2 hours' do
    let!(:hook) do
      create(:integrations_hook, :gohighlevel, account: account, settings: {
               'location_id' => 'loc_123',
               'company_id' => 'comp_456',
               'refresh_token' => 'old_refresh_token',
               'expires_at' => 1.hour.from_now.iso8601,
               'connected_at' => 2.days.ago.iso8601
             })
    end

    it 'refreshes the token' do
      expect(Ghl::TokenRefreshService).to receive(:new).with('old_refresh_token')
      job.perform
    end

    it 'updates the hook with new tokens' do
      job.perform
      hook.reload

      expect(hook.access_token).to eq('new_access_token')
      expect(hook.settings['refresh_token']).to eq('new_refresh_token')
      expect(hook.settings['expires_in']).to eq(86_400)
      expect(hook.settings['last_refreshed_at']).to be_present
    end

    it 'updates the expires_at timestamp' do
      freeze_time do
        job.perform
        hook.reload
        expect(Time.zone.parse(hook.settings['expires_at'])).to be_within(1.second).of(24.hours.from_now)
      end
    end
  end

  context 'when a hook has a token expiring after 2 hours' do
    let!(:hook) do
      create(:integrations_hook, :gohighlevel, account: account, settings: {
               'location_id' => 'loc_123',
               'refresh_token' => 'some_token',
               'expires_at' => 12.hours.from_now.iso8601
             })
    end

    it 'does not refresh the token' do
      expect(Ghl::TokenRefreshService).not_to receive(:new)
      job.perform
    end
  end

  context 'when a hook has no expires_at (proactive refresh)' do
    let!(:hook) do
      create(:integrations_hook, :gohighlevel, account: account, settings: {
               'location_id' => 'loc_123',
               'refresh_token' => 'needs_refresh'
             })
    end

    it 'refreshes proactively' do
      expect(Ghl::TokenRefreshService).to receive(:new).with('needs_refresh')
      job.perform
    end
  end

  context 'when a hook has no refresh_token' do
    let!(:hook) do
      create(:integrations_hook, :gohighlevel, account: account, settings: {
               'location_id' => 'loc_123',
               'expires_at' => 30.minutes.from_now.iso8601
             })
    end

    it 'skips the hook' do
      expect(Ghl::TokenRefreshService).not_to receive(:new)
      job.perform
    end
  end

  context 'when a hook is disabled' do
    let!(:hook) do
      create(:integrations_hook, :gohighlevel, account: account,
                                               status: Integrations::Hook.statuses['disabled'],
                                               settings: {
                                                 'location_id' => 'loc_123',
                                                 'refresh_token' => 'should_skip',
                                                 'expires_at' => 30.minutes.from_now.iso8601
                                               })
    end

    it 'skips disabled hooks' do
      expect(Ghl::TokenRefreshService).not_to receive(:new)
      job.perform
    end
  end

  context 'when the refresh service raises an error' do
    let!(:hook_ok) do
      create(:integrations_hook, :gohighlevel, account: account, settings: {
               'location_id' => 'loc_ok',
               'refresh_token' => 'token_ok',
               'expires_at' => 30.minutes.from_now.iso8601
             })
    end

    let!(:hook_fail) do
      create(:integrations_hook, :gohighlevel, account: create(:account), settings: {
               'location_id' => 'loc_fail',
               'refresh_token' => 'token_fail',
               'expires_at' => 30.minutes.from_now.iso8601
             })
    end

    let(:failing_service) { instance_double(Ghl::TokenRefreshService) }

    before do
      allow(failing_service).to receive(:refresh!).and_raise(StandardError, 'API error')
      allow(Ghl::TokenRefreshService).to receive(:new).with('token_fail').and_return(failing_service)
      allow(Ghl::TokenRefreshService).to receive(:new).with('token_ok').and_return(refresh_service)
    end

    it 'continues processing remaining hooks after a failure' do
      expect(Ghl::TokenRefreshService).to receive(:new).with('token_fail')
      expect(Ghl::TokenRefreshService).to receive(:new).with('token_ok')
      job.perform
    end

    it 'logs the error' do
      expect(Rails.logger).to receive(:error).with(/FAILED.*hook=#{hook_fail.id}/)
      allow(Rails.logger).to receive(:error) # allow backtrace log
      allow(Rails.logger).to receive(:info)
      job.perform
    end

    it 'does not raise and completes the job' do
      expect { job.perform }.not_to raise_error
    end
  end

  context 'with multiple hooks needing refresh' do
    let!(:hooks) do
      3.times.map do |i|
        create(:integrations_hook, :gohighlevel, account: create(:account), settings: {
                 'location_id' => "loc_#{i}",
                 'refresh_token' => "token_#{i}",
                 'expires_at' => (30 + i * 10).minutes.from_now.iso8601
               })
      end
    end

    it 'refreshes all expiring hooks' do
      expect(Ghl::TokenRefreshService).to receive(:new).exactly(3).times
      job.perform
    end
  end
end
