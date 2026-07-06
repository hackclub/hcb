# frozen_string_literal: true

class CreateCardCharges < ActiveRecord::Migration[8.0]
  def change
    create_table :card_charges do |t|
      t.references :raw_pending_stripe_transaction, index: { unique: true }, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    create_join_table :card_charges, :raw_stripe_transactions do |t|
      t.index :raw_stripe_transaction_id, unique: true, name: "index_card_charges_rsts_on_raw_stripe_transaction_id"
      t.index :card_charge_id, name: "index_card_charges_rsts_on_card_charge_id"
      t.foreign_key :raw_stripe_transactions, on_delete: :cascade
      t.foreign_key :card_charges, on_delete: :cascade
    end
  end

end
