class CreateWiseTransfers < ActiveRecord::Migration[7.2]
  def change
    create_table :wise_transfers do |t|
      t.string :aasm_state
      t.string :bank_name
      t.string :account_number_bidx
      t.string :account_number_ciphertext
      t.string :address_city
      t.string :address_line1
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state
      t.integer :amount_cents, null: false
      t.datetime :approved_at
      t.string :institution_number_bidx
      t.string :institution_number_ciphertext
      t.string :branch_number_bidx
      t.string :branch_number_ciphertext
      t.string :tax_id_bidx
      t.string :tax_id_ciphertext
      t.string :currency, null: false
      t.string :memo, null: false
      t.string :payment_for, null: false
      t.integer :recipient_country, null: false
      t.string :recipient_email, null: false
      t.jsonb :recipient_information
      t.string :recipient_name, null: false
      t.text :recipient_phone_number
      t.text :recipient_birthday_ciphertext
      t.text :wise_id
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
