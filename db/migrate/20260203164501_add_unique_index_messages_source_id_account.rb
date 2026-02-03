# frozen_string_literal: true

class AddUniqueIndexMessagesSourceIdAccount < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Remove existing non-unique index
    remove_index :messages, :source_id, name: 'index_messages_on_source_id', if_exists: true

    # Add unique composite index scoped to account — prevents race-condition duplicates.
    # NULL source_ids are excluded by Postgres (NULLs are always distinct), so only
    # rows with an actual source_id are constrained.
    add_index :messages, %i[account_id source_id],
              unique: true,
              name: 'index_messages_on_account_id_and_source_id_unique',
              algorithm: :concurrently,
              where: 'source_id IS NOT NULL'
  end
end
