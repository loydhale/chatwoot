module Enterprise::Concerns::Inbox
  extend ActiveSupport::Concern

  included do
    has_one :captain_inbox, dependent: :destroy, class_name: 'HudleyInbox'
    has_one :captain_assistant,
            through: :captain_inbox,
            class_name: 'Hudley::Assistant'
    has_many :inbox_capacity_limits, dependent: :destroy
  end
end
