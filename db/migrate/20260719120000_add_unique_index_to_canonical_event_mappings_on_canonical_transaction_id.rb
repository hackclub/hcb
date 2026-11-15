# frozen_string_literal: true

class AddUniqueIndexToCanonicalEventMappingsOnCanonicalTransactionId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :canonical_event_mappings, :canonical_transaction_id

    add_index :canonical_event_mappings, :canonical_transaction_id, unique: true, algorithm: :concurrently
  end
end
