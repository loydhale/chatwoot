# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::GhlController', type: :request do
  let(:webhook_secret) { 'test_webhook_secret_key_12345' }
  let(:webhook_url) { '/webhooks/ghl' }

  before do
    create(:installation_config, name: 'GHL_WEBHOOK_SECRET', value: webhook_secret)
  end

  def sign_payload(payload, secret = webhook_secret)
    OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
  end

  def post_webhook(secret: webhook_secret, **params)
    payload = params.to_json
    signature = sign_payload(payload, secret)

    post webhook_url,
         params: payload,
         headers: {
           'Content-Type' => 'application/json',
           'X-GHL-Signature' => signature
         }
  end

  # ─── Signature Verification ────────────────────────────────────────

  describe 'signature verification' do
    it 'returns 401 when signature header is missing' do
      post webhook_url,
           params: { type: 'contact.create' }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 when signature is invalid' do
      payload = { type: 'contact.create' }.to_json

      post webhook_url,
           params: payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-GHL-Signature' => 'invalid_signature_value'
           }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 when webhook secret is not configured' do
      InstallationConfig.find_by(name: 'GHL_WEBHOOK_SECRET')&.destroy
      # Also ensure no CLIENT_SECRET fallback
      InstallationConfig.find_by(name: 'GHL_CLIENT_SECRET')&.destroy

      payload = { type: 'contact.create' }.to_json

      post webhook_url,
           params: payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-GHL-Signature' => sign_payload(payload)
           }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'accepts a valid HMAC-SHA256 signature' do
      post_webhook(type: 'contact.create', contact: { id: 'c1' }, locationId: 'loc1')
      expect(response).to have_http_status(:ok)
    end

    it 'falls back to GHL_CLIENT_SECRET when GHL_WEBHOOK_SECRET is not set' do
      client_secret = 'client_secret_fallback'
      InstallationConfig.find_by(name: 'GHL_WEBHOOK_SECRET')&.destroy
      create(:installation_config, name: 'GHL_CLIENT_SECRET', value: client_secret)

      post_webhook(type: 'contact.create', contact: { id: 'c1' }, secret: client_secret)
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Contact Events ────────────────────────────────────────────────

  describe 'contact events' do
    it 'enqueues contact.create job for ContactCreate event' do
      expect do
        post_webhook(type: 'ContactCreate', contact: { id: 'ct_1', firstName: 'John' }, locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('contact.create', hash_including('type' => 'ContactCreate'))

      expect(response).to have_http_status(:ok)
    end

    it 'enqueues contact.create job for contact.create event' do
      expect do
        post_webhook(type: 'contact.create', contact: { id: 'ct_2' }, locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('contact.create', anything)

      expect(response).to have_http_status(:ok)
    end

    it 'enqueues contact.update job for ContactUpdate event' do
      expect do
        post_webhook(type: 'ContactUpdate', contact: { id: 'ct_1', email: 'new@test.com' }, locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('contact.update', anything)

      expect(response).to have_http_status(:ok)
    end

    it 'enqueues contact.delete job for ContactDelete event' do
      expect do
        post_webhook(type: 'ContactDelete', contact: { id: 'ct_1' }, locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('contact.delete', anything)

      expect(response).to have_http_status(:ok)
    end

    it 'enqueues contact.delete job for contact.delete event' do
      expect do
        post_webhook(type: 'contact.delete', contact: { id: 'ct_1' }, locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('contact.delete', anything)

      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Message Events ────────────────────────────────────────────────

  describe 'message events' do
    it 'enqueues conversation.message for InboundMessage' do
      expect do
        post_webhook(type: 'InboundMessage', contactId: 'ct_1', body: 'Hello', locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('conversation.message', anything)

      expect(response).to have_http_status(:ok)
    end

    it 'enqueues conversation.message for OutboundMessage' do
      expect do
        post_webhook(type: 'OutboundMessage', contactId: 'ct_1', body: 'Reply', locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('conversation.message', anything)

      expect(response).to have_http_status(:ok)
    end

    it 'enqueues conversation.message for ConversationProviderOutboundMessage' do
      expect do
        post_webhook(type: 'ConversationProviderOutboundMessage', contactId: 'ct_1', body: 'Auto', locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('conversation.message', anything)
    end

    it 'enqueues conversation.status for ConversationUnreadUpdate' do
      expect do
        post_webhook(type: 'ConversationUnreadUpdate', conversationId: 'conv_1', status: 'read', locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('conversation.status', anything)
    end

    it 'enqueues conversation.status for ConversationAssignmentUpdate' do
      expect do
        post_webhook(type: 'ConversationAssignmentUpdate', conversationId: 'conv_1', locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('conversation.status', anything)
    end
  end

  # ─── Opportunity Events ────────────────────────────────────────────

  describe 'opportunity events' do
    it 'enqueues opportunity.create for OpportunityCreate' do
      expect do
        post_webhook(
          type: 'OpportunityCreate',
          opportunity: { id: 'opp_1', name: 'New Deal', pipelineName: 'Sales' },
          locationId: 'loc1'
        )
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('opportunity.create', anything)

      expect(response).to have_http_status(:ok)
    end

    it 'enqueues opportunity.create for opportunity.create event' do
      expect do
        post_webhook(
          type: 'opportunity.create',
          opportunity: { id: 'opp_2', name: 'Another Deal' },
          locationId: 'loc1'
        )
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('opportunity.create', anything)
    end

    it 'enqueues opportunity.update for OpportunityUpdate' do
      expect do
        post_webhook(
          type: 'OpportunityUpdate',
          opportunity: { id: 'opp_1', monetaryValue: 5000 },
          locationId: 'loc1'
        )
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('opportunity.update', anything)
    end

    it 'enqueues opportunity.delete for OpportunityDelete' do
      expect do
        post_webhook(
          type: 'OpportunityDelete',
          opportunity: { id: 'opp_1' },
          locationId: 'loc1'
        )
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('opportunity.delete', anything)
    end

    it 'enqueues opportunity.status_change for OpportunityStageUpdate' do
      expect do
        post_webhook(
          type: 'OpportunityStageUpdate',
          opportunity: { id: 'opp_1', stageName: 'Negotiation' },
          locationId: 'loc1'
        )
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('opportunity.status_change', anything)
    end

    it 'enqueues opportunity.status_change for OpportunityStatusUpdate' do
      expect do
        post_webhook(
          type: 'OpportunityStatusUpdate',
          opportunity: { id: 'opp_1', status: 'won' },
          locationId: 'loc1'
        )
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('opportunity.status_change', anything)
    end

    it 'enqueues opportunity.update for OpportunityMonetaryValueUpdate' do
      expect do
        post_webhook(
          type: 'OpportunityMonetaryValueUpdate',
          opportunity: { id: 'opp_1', monetaryValue: 10_000 },
          locationId: 'loc1'
        )
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('opportunity.update', anything)
    end
  end

  # ─── App Lifecycle Events ──────────────────────────────────────────

  describe 'app lifecycle events' do
    it 'enqueues app.installed for AppInstalled' do
      expect do
        post_webhook(type: 'AppInstalled', locationId: 'loc1', companyId: 'comp1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('app.installed', anything)
    end

    it 'enqueues app.uninstalled for AppUninstalled' do
      expect do
        post_webhook(type: 'AppUninstalled', locationId: 'loc1', companyId: 'comp1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('app.uninstalled', anything)
    end
  end

  # ─── Location Events ───────────────────────────────────────────────

  describe 'location events' do
    it 'enqueues location.create for LocationCreate' do
      expect do
        post_webhook(type: 'LocationCreate', location: { id: 'loc_new', name: 'Branch 2' })
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('location.create', anything)
    end

    it 'enqueues location.update for LocationUpdate' do
      expect do
        post_webhook(type: 'LocationUpdate', location: { id: 'loc1', name: 'Updated Name' })
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with('location.update', anything)
    end
  end

  # ─── Unknown Events ────────────────────────────────────────────────

  describe 'unknown events' do
    it 'returns 200 for unknown event types (graceful handling)' do
      expect do
        post_webhook(type: 'SomeUnknownEvent', data: { foo: 'bar' })
      end.not_to have_enqueued_job(Webhooks::GhlEventsJob)

      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Params Sanitization ───────────────────────────────────────────

  describe 'params sanitization' do
    it 'strips controller and action from dispatched params' do
      expect do
        post_webhook(type: 'contact.create', contact: { id: 'ct_1' }, locationId: 'loc1')
      end.to have_enqueued_job(Webhooks::GhlEventsJob).with(
        'contact.create',
        hash_not_including('controller', 'action')
      )
    end
  end
end
