# frozen_string_literal: true

class CreateLedgerSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_subscriptions do |t|
      t.references :ledger, null: false, foreign_key: true, index: false
      t.references :payment_rail, polymorphic: true, null: false
      t.string :merchant_key, null: false
      t.string :name, null: false
      t.integer :amount_cents, null: false
      t.boolean :variable_amount, null: false, default: false
      t.integer :cadence_days, null: false
      t.integer :confidence, null: false, default: 0
      t.datetime :last_charged_at, null: false
      t.datetime :next_expected_at, null: false

      t.timestamps
    end

    add_index :ledger_subscriptions, [:ledger_id, :merchant_key]
  end

end
