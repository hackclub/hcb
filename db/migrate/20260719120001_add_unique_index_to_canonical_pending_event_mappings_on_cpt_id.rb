# frozen_string_literal: true

class AddUniqueIndexToCanonicalPendingEventMappingsOnCptId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :canonical_pending_event_mappings, :canonical_pending_transaction_id

    add_index :canonical_pending_event_mappings, :canonical_pending_transaction_id, unique: true, name: "index_canonical_pending_event_map_on_canonical_pending_tx_id", algorithm: :concurrently
  end
end
