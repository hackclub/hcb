class AddRecipientNameToUserPayoutMethodWires < ActiveRecord::Migration[8.0]
  def change
    add_column :user_payout_method_wires, :recipient_name, :string
  end
end
