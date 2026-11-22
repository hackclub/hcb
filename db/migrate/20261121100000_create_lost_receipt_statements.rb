# frozen_string_literal: true

class CreateLostReceiptStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :lost_receipt_statements do |t|
      # Null until the PDF has been generated and attached.
      t.references :receipt, foreign_key: true, index: { unique: true }
      # Null when the statement came through the emailed receipt link.
      t.references :submitter, foreign_key: { to_table: :users }
      t.string :merchant, null: false
      t.date :date, null: false
      t.text :purpose, null: false
      t.integer :total_amount_cents, null: false
      t.string :signer_name, null: false
      t.datetime :confirmed_at, null: false

      t.timestamps
    end

    create_table :lost_receipt_items do |t|
      t.references :statement, null: false, foreign_key: { to_table: :lost_receipt_statements }
      t.string :description, null: false
      t.integer :quantity, null: false
      t.integer :unit_amount_cents, null: false

      t.timestamps
    end
  end

end
