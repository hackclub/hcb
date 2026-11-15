# frozen_string_literal: true

class CreateLostReceiptStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :lost_receipt_statements do |t|
      t.references :receipt, null: false, foreign_key: true, index: { unique: true }
      t.references :event, foreign_key: true
      # Null when the statement came through the emailed receipt link.
      t.references :submitter, foreign_key: { to_table: :users }
      t.string :merchant, null: false
      t.date :date, null: false
      t.text :purpose, null: false
      t.jsonb :items, null: false, default: []
      t.integer :total_amount_cents, null: false
      t.string :signer_name, null: false
      t.datetime :confirmed_at, null: false

      t.timestamps
    end
  end

end
