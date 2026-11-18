# frozen_string_literal: true

class CreateTransactionSplits < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_splits do |t|
      t.references :splittable, polymorphic: true, null: false
      t.references :transaction_category, foreign_key: true
      t.integer :amount_cents, null: false
      t.text :memo

      t.timestamps
    end
  end

end
