# frozen_string_literal: true

class CreateReimbursementWiseTransferDrafts < ActiveRecord::Migration[7.0]
  def change
    create_table :reimbursement_wise_transfer_drafts do |t|
      t.references :reimbursement_report, null: false, foreign_key: true, index: { unique: true, name: "idx_r_wise_transfer_drafts_on_report_id" }
      t.string :currency, null: false
      t.string :recipient_name, null: false
      t.string :recipient_email, null: false
      t.string :recipient_phone_number
      t.string :bank_name
      t.string :address_line1
      t.string :address_line2
      t.string :address_city
      t.string :address_state
      t.string :address_postal_code
      t.integer :recipient_country
      t.text :recipient_information_ciphertext
      t.timestamps
    end
  end
end
