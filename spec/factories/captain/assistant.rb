FactoryBot.define do
  factory :captain_assistant, class: 'Hudley::Assistant' do
    sequence(:name) { |n| "Assistant #{n}" }
    description { 'Test description' }
    association :account
  end
end
