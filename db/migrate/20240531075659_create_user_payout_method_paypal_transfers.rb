class CreateUserPayoutMethodPaypalTransfers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    create_table :user_payout_method_paypal_transfers do |t|
      t.text :recipient_email, null: false
      t.timestamps
    end
    add_reference :reimbursement_payout_holdings, :paypal_transfer, null: true, index: { algorithm: :concurrently }
  end
end
