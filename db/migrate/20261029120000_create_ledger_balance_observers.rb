# frozen_string_literal: true

class CreateLedgerBalanceObservers < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_balance_observers do |t|
      t.references :ledger, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.datetime :notified_at

      t.timestamps
    end

    add_index :ledger_balance_observers, [:ledger_id, :user_id], unique: true
  end

end
