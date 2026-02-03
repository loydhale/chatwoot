# frozen_string_literal: true

class AddGhlIndexesToIntegrationsHooks < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Composite index for GHL webhook lookup:
    #   Integrations::Hook.find_by(app_id: 'gohighlevel', status: 'enabled', reference_id: location_id)
    add_index :integrations_hooks, %i[app_id status reference_id],
              name: 'index_integrations_hooks_on_app_status_reference',
              algorithm: :concurrently,
              if_not_exists: true

    # Index on app_id alone for general integration lookups
    add_index :integrations_hooks, :app_id,
              name: 'index_integrations_hooks_on_app_id',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
