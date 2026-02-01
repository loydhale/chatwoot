# frozen_string_literal: true

class Webhooks::GhlController < ActionController::API
  before_action :verify_signature

  def process_payload
    event_type = params[:type] || params[:event]

    case event_type
    when 'ContactCreate', 'contact.create'
      Webhooks::GhlEventsJob.perform_later('contact.create', params.to_unsafe_hash)
    when 'ContactUpdate', 'contact.update'
      Webhooks::GhlEventsJob.perform_later('contact.update', params.to_unsafe_hash)
    when 'ContactDelete', 'contact.delete'
      Webhooks::GhlEventsJob.perform_later('contact.delete', params.to_unsafe_hash)
    when 'InboundMessage', 'OutboundMessage', 'ConversationProviderOutboundMessage',
         'conversation.message'
      Webhooks::GhlEventsJob.perform_later('conversation.message', params.to_unsafe_hash)
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
end
