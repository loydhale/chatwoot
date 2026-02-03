# frozen_string_literal: true

class AddEncryptedRefreshTokenToHooks < ActiveRecord::Migration[7.0]
  def change
    add_column :integrations_hooks, :refresh_token, :string
  end
end
