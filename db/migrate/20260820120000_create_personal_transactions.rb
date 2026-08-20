# frozen_string_literal: true

class CreatePersonalTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :personal_transactions do |t|
      t.references :ledger_item, foreign_key: { to_table: :ledger_items }, index: { unique: true }
      t.references :invoice, foreign_key: true
      t.references :reporter, foreign_key: { to_table: :users }
      t.timestamps
    end
  end

end
