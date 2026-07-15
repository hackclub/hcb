# frozen_string_literal: true

class CreateRawPendingFeeRevenueTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :raw_pending_fee_revenue_transactions do |t|
      t.string :fee_revenue_transaction_id, null: false
      t.integer :amount_cents, null: false
      t.date :date_posted, null: false

      t.timestamps

      t.index :fee_revenue_transaction_id, unique: true, name: :index_raw_pending_fee_revenue_txs_on_fee_revenue_tx_id
    end
  end

end
