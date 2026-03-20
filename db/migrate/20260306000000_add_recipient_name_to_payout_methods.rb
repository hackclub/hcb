class AddRecipientNameToPayoutMethods < ActiveRecord::Migration[8.0]
  def up
    add_column :user_payout_method_checks, :recipient_name, :string, limit: 255
    add_column :user_payout_method_ach_transfers, :recipient_name, :string, limit: 255
    add_column :user_payout_method_paypal_transfers, :recipient_name, :string, limit: 255
    add_column :user_payout_method_wise_transfers, :recipient_name, :string, limit: 255

    # Migrate account_holder from recipient_information into recipient_name for WiseTransfer
    User::PayoutMethod::WiseTransfer.find_each do |wise_transfer|
      account_holder = wise_transfer.recipient_information&.dig("account_holder")
      next if account_holder.blank?

      wise_transfer.update_columns(recipient_name: account_holder)
    end
  end

  def down
    remove_column :user_payout_method_checks, :recipient_name
    remove_column :user_payout_method_ach_transfers, :recipient_name
    remove_column :user_payout_method_paypal_transfers, :recipient_name
    remove_column :user_payout_method_wise_transfers, :recipient_name
  end
end
