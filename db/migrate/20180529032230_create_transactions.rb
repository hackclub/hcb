# frozen_string_literal: true

class CreateTransactions < ActiveRecord::Migration[5.2]
  def change
    create_table :transact_so_ns do |t|
      t.text :plaid_id
      t.text :transaction_type
      t.text :plaid_category_id
      t.text :name
      t.bigint :amount
      t.date :date
      t.text :location_address
      t.text :location_city
      t.text :location_state
      t.text :location_zip
      t.decimal :location_lat
      t.decimal :location_lng
      t.text :payment_meta_reference_number
      t.text :payment_meta_ppd_id
      t.text :payment_meta_payee_name
      t.boolean :pending
      t.text :pending_transaction_id

      t.timestamps
    end
  end

end
