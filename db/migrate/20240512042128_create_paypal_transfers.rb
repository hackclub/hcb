class CreatePaypalTransfers < ActiveRecord::Migration[7.0]
  def change
    create_table :paypal_transfers do |t|
      t.string :memo, null: false
      t.string :payment_for, null: false
      t.integer :amount_cents, null: false
      t.string :recipient_name, null: false
      t.string :recipient_email, null: false
      t.string :aasm_state, null: false
      t.datetime :approved_at
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
