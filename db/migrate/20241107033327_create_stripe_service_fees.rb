class CreateStripeServiceFees < ActiveRecord::Migration[7.2]
  def change
    create_table :stripe_service_fees do |t|
      t.string :stripe_balance_transaction_id, index: { unique: true }, null: false
      t.string :stripe_topup_id, index: { unique: true }
      t.integer :amount_cents, null: false
      t.string :stripe_description, null: false

      t.timestamps
    end
  end
end
