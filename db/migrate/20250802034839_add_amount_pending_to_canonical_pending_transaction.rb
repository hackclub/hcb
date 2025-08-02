class AddAmountPendingToCanonicalPendingTransaction < ActiveRecord::Migration[7.2]
  def change
    add_column :canonical_pending_transactions, :amount_pending, :boolean, default: false, null: false
  end
end
