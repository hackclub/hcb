class CreateWiseTransfers < ActiveRecord::Migration[7.2]
  def change
    create_table :wise_transfers do |t|
      t.string :aasm_state
      t.string :bank_name
      t.string :address_city
      t.string :address_line1
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state
      t.integer :amount_cents, null: false
      t.datetime :approved_at
      t.datetime :sent_at
      t.string :currency, null: false
      t.string :payment_for, null: false
      t.integer :recipient_country, null: false
      t.string :recipient_email, null: false
      t.text :recipient_information_ciphertext
      t.string :recipient_name, null: false
      t.text :recipient_phone_number
      t.text :return_reason
      t.integer :quoted_usd_amount_cents
      t.text :wise_id
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
