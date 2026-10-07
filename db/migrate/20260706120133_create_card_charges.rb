# frozen_string_literal: true

class CreateCardCharges < ActiveRecord::Migration[8.0]
  def change
    create_table :card_charges do |t|
      t.references :raw_pending_stripe_transaction, index: { unique: true }, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    create_table :card_charge_raw_stripe_transactions do |t|
      t.references :card_charge, null: false, foreign_key: { on_delete: :cascade }
      t.references :raw_stripe_transaction, null: false, index: { unique: true, name: "index_card_charge_rsts_on_raw_stripe_transaction_id" }, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end

end
