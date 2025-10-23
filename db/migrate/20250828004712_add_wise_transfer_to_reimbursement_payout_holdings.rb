class AddWiseTransferToReimbursementPayoutHoldings < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :reimbursement_payout_holdings, :wise_transfer, null: true, index: { algorithm: :concurrently }
  end
end
