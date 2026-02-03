# frozen_string_literal: true

class CreateGhlSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :ghl_subscriptions do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :plan, null: false, default: 'starter'
      t.string :status, null: false, default: 'trialing'
      t.string :ghl_company_id
      t.string :ghl_location_id
      t.string :ghl_user_id
      t.string :ghl_app_id
      t.integer :locations_count, null: false, default: 1
      t.integer :locations_limit, null: false, default: 1
      t.integer :agents_limit, null: false, default: 3
      t.integer :ai_credits_used, null: false, default: 0
      t.integer :ai_credits_limit, null: false, default: 500
      t.jsonb :usage_data, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :trial_ends_at
      t.datetime :current_period_ends_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :ghl_subscriptions, :ghl_company_id
    add_index :ghl_subscriptions, :ghl_location_id
    add_index :ghl_subscriptions, :plan
    add_index :ghl_subscriptions, :status

    # Add GHL-specific fields to accounts for quick lookups
    add_column :accounts, :ghl_location_id, :string
    add_column :accounts, :ghl_company_id, :string
    add_index :accounts, :ghl_location_id, unique: true, where: 'ghl_location_id IS NOT NULL'
    add_index :accounts, :ghl_company_id
  end
end
