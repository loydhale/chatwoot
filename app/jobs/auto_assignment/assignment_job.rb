class AutoAssignment::AssignmentJob < ApplicationJob
  queue_as :default

  def perform(inbox_id:)
    inbox = Inbox.find_by(id: inbox_id)
    return unless inbox

    service = AutoAssignment::AssignmentService.new(inbox: inbox)

    assigned_count = service.perform_bulk_assignment(limit: bulk_assignment_limit)
    Rails.logger.info "Assigned #{assigned_count} conversations for inbox #{inbox.id}"
  rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout,
         Redis::CannotConnectError, Redis::TimeoutError,
         ActiveRecord::ConnectionNotEstablished,
         ActiveRecord::Deadlocked => e
    # Transient errors — log and re-raise for Sidekiq retry
    Rails.logger.error "Bulk assignment transient error for inbox #{inbox_id}: #{e.class} — #{e.message}"
    raise
  rescue StandardError => e
    # Permanent failures — log but swallow to prevent infinite retries
    Rails.logger.error "Bulk assignment permanent error for inbox #{inbox_id}: #{e.class} — #{e.message}"
  end

  private

  def bulk_assignment_limit
    ENV.fetch('AUTO_ASSIGNMENT_BULK_LIMIT', 100).to_i
  end
end
