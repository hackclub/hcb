class CreateUserPayoutMethodWiseTransfers < ActiveRecord::Migration[7.2]
  def change
    create_table :user_payout_method_wise_transfers do |t|
      t.string :address_city
      t.string :address_line1
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state
      t.string :bank_name
      t.integer :recipient_country
      t.text :recipient_information_ciphertext
      t.string :currency

      t.timestamps
    end
  end
end
