class AddPayPalTransferToCanonicalPendingTransaction < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  
  def change
    add_reference :canonical_pending_transactions, :paypal_transfer, null: true, index: { algorithm: :concurrently }
  end
end
