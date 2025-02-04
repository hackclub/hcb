class CreateUserPayoutMethodWires < ActiveRecord::Migration[7.2]
  def change
    create_table :user_payout_method_wires do |t|
      t.string :recipient_account_number_ciphertext, null: false
      t.string :recipient_account_number_bidx, null: false
      t.string :bic_code_ciphertext, null: false
      t.string :bic_code_bidx, null: false
      t.integer :recipient_country
      t.jsonb :recipient_information
      t.string :address_city
      t.string :address_line1
      t.string :address_line2
      t.string :address_state
      t.string :address_postal_code

      t.timestamps
    end
  end
end
