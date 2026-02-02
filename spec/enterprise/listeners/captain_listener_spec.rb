require 'rails_helper'

describe HudleyListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:user) { create(:user, account: account) }
  let(:assistant) { create(:captain_assistant, account: account, config: { feature_memory: true, feature_faq: true }) }

  describe '#conversation_resolved' do
    let(:agent) { create(:user, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

    let(:event_name) { :conversation_resolved }
    let(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

    before do
      create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
    end

    context 'when feature_memory is enabled' do
      before do
        assistant.config['feature_memory'] = true
        assistant.config['feature_faq'] = false
        assistant.save!
      end

      it 'generates and updates notes' do
        expect(Hudley::Llm::ContactNotesService)
          .to receive(:new)
          .with(assistant, conversation)
          .and_return(instance_double(Hudley::Llm::ContactNotesService, generate_and_update_notes: nil))
        expect(Hudley::Llm::ConversationFaqService).not_to receive(:new)

        listener.conversation_resolved(event)
      end
    end

    context 'when feature_faq is enabled' do
      before do
        assistant.config['feature_faq'] = true
        assistant.config['feature_memory'] = false
        assistant.save!
      end

      it 'generates and deduplicates FAQs' do
        expect(Hudley::Llm::ConversationFaqService)
          .to receive(:new)
          .with(assistant, conversation)
          .and_return(instance_double(Hudley::Llm::ConversationFaqService, generate_and_deduplicate: false))
        expect(Hudley::Llm::ContactNotesService).not_to receive(:new)

        listener.conversation_resolved(event)
      end
    end
  end
end
