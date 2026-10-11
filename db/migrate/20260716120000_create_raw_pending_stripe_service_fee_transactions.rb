class CreateRawPendingStripeServiceFeeTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    create_table :raw_pending_stripe_service_fee_transactions do |t|
      t.integer :amount_cents
      t.date :date_posted
      t.references :stripe_service_fee, null: false, foreign_key: true, index: { name: "index_rp_stripe_service_fee_txs_on_stripe_service_fee_id" }

      t.timestamps
    end

    add_reference :canonical_pending_transactions, :raw_pending_stripe_service_fee_transaction, null: true, index: { name: "index_cpts_on_raw_pending_stripe_service_fee_tx_id", algorithm: :concurrently }
  end
end
