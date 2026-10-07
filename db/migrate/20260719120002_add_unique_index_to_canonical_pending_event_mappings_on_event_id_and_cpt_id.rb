# frozen_string_literal: true

class AddUniqueIndexToCanonicalPendingEventMappingsOnEventIdAndCptId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :canonical_pending_event_mappings, [:event_id, :canonical_pending_transaction_id], unique: true, name: "index_cpem_event_id_cpt_id_uniqueness", algorithm: :concurrently
  end
end
