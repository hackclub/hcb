# frozen_string_literal: true

class CreateLedgerItems < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_items do |t|
      t.integer :amount_cents, null: false
      t.text :memo, null: false
      t.datetime :date, null: false

      t.text :short_code

      t.datetime :marked_no_or_lost_receipt_at

      t.timestamps
    end
  end

end
