# frozen_string_literal: true

class CreateLedgerMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_mappings do |t|
      t.references :ledger, null: false, foreign_key: true
      t.references :ledger_item, null: false, foreign_key: true
      t.boolean :on_primary_ledger, null: false

      t.references :mapped_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Enforce that ledger_item_id is unique when on_primary_ledger is true
    add_index :ledger_mappings, :ledger_item_id,
              unique: true,
              where: "on_primary_ledger = true",
              name: "index_ledger_mappings_unique_item_on_primary"
  end
end
