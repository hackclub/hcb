# frozen_string_literal: true

class CreateRepayments < ActiveRecord::Migration[8.1]
  def change
    create_table :repayments do |t|
      t.references :disbursement, null: false, foreign_key: true
      t.references :ledger_item, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.jsonb :previous_categories, null: false, default: {}

      t.timestamps
    end

    add_index :repayments, [:disbursement_id, :ledger_item_id], unique: true
  end

end
