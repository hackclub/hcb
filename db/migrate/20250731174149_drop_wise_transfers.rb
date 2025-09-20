class DropWiseTransfers < ActiveRecord::Migration[7.2]
  def change
    drop_table :wise_transfers, if_exists: true do |t|
      t.string :aasm_state
      t.string :bank_name
      t.string :account_number_bidx
      t.string :account_number_ciphertext
      t.string :address_city
      t.string :address_line1
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state
      t.integer :amount_cents
      t.datetime :approved_at
      t.string :bic_code_bidx
      t.string :bic_code_ciphertext
      t.string :currency
      t.string :memo
      t.string :payment_for
      t.integer :recipient_country
      t.string :recipient_email
      t.jsonb :recipient_information
      t.string :recipient_name
      t.text :recipient_phone_number
      t.text :recipient_birthday_ciphertext
      t.text :wise_id
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
