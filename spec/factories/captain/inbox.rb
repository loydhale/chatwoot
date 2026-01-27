FactoryBot.define do
  factory :captain_inbox, class: 'AtlasInbox' do
    association :captain_assistant, factory: :captain_assistant
    association :inbox
  end
end
