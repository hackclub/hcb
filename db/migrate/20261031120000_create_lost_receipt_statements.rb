# frozen_string_literal: true

class CreateLostReceiptStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :lost_receipt_statements do |t|
      t.references :receipt, null: false, foreign_key: true, index: { unique: true }
      t.references :submitter, foreign_key: { to_table: :users }
      t.date :date, null: false
      t.string :merchant, null: false
      t.text :purpose, null: false
      t.string :signer_name, null: false
      t.datetime :confirmed_at, null: false
      t.timestamps
    end

    create_table :lost_receipt_items do |t|
      t.references :statement, null: false, foreign_key: { to_table: :lost_receipt_statements }
      t.string :description, null: false
      t.integer :quantity, null: false
      t.bigint :unit_amount_cents, null: false
      t.timestamps
    end
  end
end
