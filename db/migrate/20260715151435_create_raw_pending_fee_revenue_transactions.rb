class CreateRawPendingFeeRevenueTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :raw_pending_fee_revenue_transactions do |t|
      t.integer :amount_cents
      t.date :date_posted
      t.references :fee_revenue, null: false, foreign_key: true

      t.timestamps
    end

    add_reference :canonical_pending_transactions, :raw_pending_fee_revenue_transaction, null: true, foreign_key: true, index: { name: "index_canonical_pending_txs_on_raw_pending_fee_revenue_tx_id" }
  end
end
