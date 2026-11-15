class AddStripeTopupToFeeReimbursement < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_reference :fee_reimbursements, :stripe_topup, index: {algorithm: :concurrently}
  end
end
