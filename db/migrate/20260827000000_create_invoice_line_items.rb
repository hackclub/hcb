# frozen_string_literal: true

class CreateInvoiceLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.text :description, null: false
      t.bigint :amount, null: false
      t.text :item_stripe_id

      t.timestamps

      t.index :item_stripe_id, unique: true
    end
  end
end
