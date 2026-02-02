module Enterprise::Account::ConversationsResolutionSchedulerJob
  def perform
    super

    resolve_captain_conversations
  end

  private

  def resolve_captain_conversations
    HudleyInbox.all.find_each(batch_size: 100) do |captain_inbox|
      inbox = captain_inbox.inbox

      next if inbox.email?

      Hudley::InboxPendingConversationsResolutionJob.perform_later(
        inbox
      )
    end
  end
end
