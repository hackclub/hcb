# frozen_string_literal: true

class CreateStripeCardCharges < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_card_charges do |t|
      t.references :raw_pending_stripe_transaction, index: { unique: true }, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    create_join_table :raw_stripe_transactions, :stripe_card_charges do |t|
      t.index :raw_stripe_transaction_id, unique: true
      t.index :stripe_card_charge_id
      t.foreign_key :raw_stripe_transactions, on_delete: :cascade
      t.foreign_key :stripe_card_charges, on_delete: :cascade
    end
  end

end
