class AddWiseRecipientIdToUserPayoutMethodWiseTransfer < ActiveRecord::Migration[7.2]
  def change
    add_column :user_payout_method_wise_transfers, :wise_recipient_id, :text
  end
end
