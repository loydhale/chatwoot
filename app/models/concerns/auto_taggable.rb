# frozen_string_literal: true

# AutoTaggable concern — automatically applies labels to conversations
# based on keyword detection in incoming messages.
# Include in Message model or call from message processing jobs.
module AutoTaggable
  extend ActiveSupport::Concern

  AUTO_TAG_RULES = {
    'billing' => %w[
      bill billing invoice payment charge charged refund
      credit\ card insurance copay co-pay deductible
      receipt statement balance owe price cost fee
      expensive overcharged transaction pay paid
    ],
    'appointment' => %w[
      appointment schedule scheduling book booking
      reschedule cancel\ appointment availability available
      slot time\ slot visit come\ in check-in checkin
      walk-in walkin next\ available earliest opening
    ],
    'membership' => %w[
      membership member subscribe subscription plan
      upgrade downgrade cancel\ membership renew renewal
      benefits tier credits points loyalty VIP premium
      package monthly annual
    ],
    'complaint' => %w[
      complaint complain upset angry furious terrible
      horrible worst awful disappointed disappointing
      unacceptable disgusted rude unprofessional
      poor\ service bad\ experience never\ coming\ back
      want\ to\ speak\ to\ manager manager supervisor
      escalate not\ happy dissatisfied frustrated ridiculous
    ],
    'new-patient' => %w[
      new\ patient first\ time first\ visit never\ been
      new\ here just\ moved looking\ for\ a accepting\ new
      new\ client getting\ started sign\ up register registration
    ],
    'urgent' => %w[
      urgent emergency asap immediately right\ away
      critical severe pain bleeding allergic\ reaction
      chest\ pain help\ now
    ]
  }.freeze

  class_methods do
    def detect_auto_tags(text)
      return [] if text.blank?

      downcased = text.downcase
      matches = []

      AUTO_TAG_RULES.each do |label, keywords|
        matched = keywords.select { |kw| downcased.include?(kw.downcase) }
        matches << label if matched.any?
      end

      matches
    end
  end

  # Instance method: auto-tag the parent conversation based on this message
  def auto_tag_conversation!
    return unless conversation.present? && content.present?
    return unless incoming? # Only tag on incoming messages

    detected = self.class.detect_auto_tags(content)
    return if detected.empty?

    account = conversation.account
    existing_labels = conversation.label_list

    detected.each do |label_name|
      next if existing_labels.include?(label_name)

      # Create the label if it doesn't exist in the account
      unless account.labels.exists?(title: label_name)
        color = auto_tag_color(label_name)
        account.labels.create!(
          title: label_name,
          description: "Auto-generated tag for #{label_name} conversations",
          color: color,
          show_on_sidebar: true
        )
      end

      conversation.label_list.add(label_name)
    end

    conversation.save! if conversation.label_list_changed?
  end

  private

  def auto_tag_color(label_name)
    colors = {
      'billing' => '#F59E0B',
      'appointment' => '#3B82F6',
      'membership' => '#8B5CF6',
      'complaint' => '#EF4444',
      'new-patient' => '#10B981',
      'urgent' => '#DC2626'
    }
    colors[label_name] || '#6B7280'
  end
end
