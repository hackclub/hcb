# frozen_string_literal: true

class CreateLedgerItemPins < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_item_pins do |t|
      t.references :ledger_item, null: false, foreign_key: true

      t.timestamps
    end
  end
end
