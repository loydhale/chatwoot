# frozen_string_literal: true

class AutoTagJob < ApplicationJob
  queue_as :low

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    message.auto_tag_conversation!
  rescue StandardError => e
    Rails.logger.warn("AutoTagJob failed for message #{message_id}: #{e.message}")
  end
end
