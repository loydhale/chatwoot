# frozen_string_literal: true

# Audit batch 3: Add missing foreign key indexes identified by vivid-slug agent.
# These indexes improve JOIN/WHERE performance on FK columns that lacked indexes.
# Uses if_not_exists: true for idempotent safety.
class AddMissingFkIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Join tables
    add_index :agent_bot_inboxes, :inbox_id, algorithm: :concurrently, if_not_exists: true
    add_index :agent_bot_inboxes, :agent_bot_id, algorithm: :concurrently, if_not_exists: true
    add_index :agent_bot_inboxes, :account_id, algorithm: :concurrently, if_not_exists: true

    # Folders
    add_index :folders, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :folders, :category_id, algorithm: :concurrently, if_not_exists: true

    # Integrations hooks (account_id, inbox_id)
    add_index :integrations_hooks, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :integrations_hooks, :inbox_id, algorithm: :concurrently, if_not_exists: true

    # Webhooks
    add_index :webhooks, :inbox_id, algorithm: :concurrently, if_not_exists: true

    # Content tables
    add_index :article_embeddings, :article_id, algorithm: :concurrently, if_not_exists: true
    add_index :articles, :category_id, algorithm: :concurrently, if_not_exists: true
    add_index :articles, :folder_id, algorithm: :concurrently, if_not_exists: true

    # Campaigns / Macros / Account users
    add_index :campaigns, :sender_id, algorithm: :concurrently, if_not_exists: true
    add_index :macros, :created_by_id, algorithm: :concurrently, if_not_exists: true
    add_index :macros, :updated_by_id, algorithm: :concurrently, if_not_exists: true
    add_index :account_users, :inviter_id, algorithm: :concurrently, if_not_exists: true

    # Channel tables — account_id indexes
    add_index :channel_api, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_email, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_instagram, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_line, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_sms, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_telegram, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_tiktok, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_twilio_sms, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_web_widgets, :account_id, algorithm: :concurrently, if_not_exists: true
    add_index :channel_whatsapp, :account_id, algorithm: :concurrently, if_not_exists: true
  end
end
