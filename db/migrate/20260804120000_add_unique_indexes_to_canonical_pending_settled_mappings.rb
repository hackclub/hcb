# frozen_string_literal: true

class AddUniqueIndexesToCanonicalPendingSettledMappings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :canonical_pending_settled_mappings, :canonical_pending_transaction_id

    add_index :canonical_pending_settled_mappings, :canonical_pending_transaction_id,
              unique: true, algorithm: :concurrently,
              name: "index_cpsm_on_cpt_id"
  end
end
