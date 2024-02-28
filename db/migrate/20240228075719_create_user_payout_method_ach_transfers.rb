class CreateUserPayoutMethodAchTransfers < ActiveRecord::Migration[7.0]
  def change
    create_table :user_payout_method_ach_transfers do |t|
      t.text :account_number_ciphertext
      t.text :routing_number_ciphertext
      t.timestamps
    end
  end
end
