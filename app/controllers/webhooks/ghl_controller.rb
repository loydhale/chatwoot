# frozen_string_literal: true

# Receives webhook events from GoHighLevel.
#
# POST /webhooks/ghl
#
# All events are verified via HMAC-SHA256 signature, then dispatched
# to background jobs for processing. Returns 200 immediately.
#
# See docs/GHL-OAUTH.md for event types and architecture.
class Webhooks::GhlController < ActionController::API
  before_action :verify_signature

  def process_payload
    event_type = params[:type] || params[:event]

    Rails.logger.info("GHL webhook received: event=#{event_type} location=#{extract_location_id}")

    case event_type
    when 'ContactCreate', 'contact.create'
      Webhooks::GhlEventsJob.perform_later('contact.create', sanitized_params)
    when 'ContactUpdate', 'contact.update'
      Webhooks::GhlEventsJob.perform_later('contact.update', sanitized_params)
    when 'ContactDelete', 'contact.delete'
      Webhooks::GhlEventsJob.perform_later('contact.delete', sanitized_params)
    when 'InboundMessage', 'OutboundMessage', 'ConversationProviderOutboundMessage',
         'conversation.message'
      Webhooks::GhlEventsJob.perform_later('conversation.message', sanitized_params)
    else
      Rails.logger.info("GHL webhook: unhandled event type '#{event_type}'")
    end

    head :ok
  end

  private

  def verify_signature
    signature = request.headers['X-GHL-Signature']
    return head :unauthorized if signature.blank?

    payload = request.raw_post
    secret  = ghl_webhook_secret
    return head :unauthorized if secret.blank?

    expected = OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
    return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end

  def ghl_webhook_secret
    GlobalConfigService.load('GHL_WEBHOOK_SECRET', nil) ||
      GlobalConfigService.load('GHL_CLIENT_SECRET', nil)
  end

  def sanitized_params
    params.to_unsafe_hash.except('controller', 'action')
  end

  def extract_location_id
    params['locationId'] || params.dig('contact', 'locationId') || params.dig('data', 'locationId')
  end
end
