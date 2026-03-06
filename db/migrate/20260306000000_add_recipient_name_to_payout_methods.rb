class AddRecipientNameToPayoutMethods < ActiveRecord::Migration[8.0]
  def change
    add_column :user_payout_method_checks, :recipient_name, :string
    add_column :user_payout_method_ach_transfers, :recipient_name, :string
    add_column :user_payout_method_paypal_transfers, :recipient_name, :string
    add_column :user_payout_method_wise_transfers, :recipient_name, :string
  end
end
