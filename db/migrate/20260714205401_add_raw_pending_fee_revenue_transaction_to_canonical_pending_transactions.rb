# frozen_string_literal: true

class AddRawPendingFeeRevenueTransactionToCanonicalPendingTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :canonical_pending_transactions, :raw_pending_fee_revenue_transaction, null: true, index: { name: :index_canonical_pending_txs_on_raw_pending_fee_revenue_tx_id, unique: true, algorithm: :concurrently }
  end

end
