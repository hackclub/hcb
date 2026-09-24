class CreatePaymentAttempts < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_attempts do |t|
      t.belongs_to :payment, null: false
      t.belongs_to :payout, polymorphic: true
      t.belongs_to :payout_method, null: false

      t.string :aasm_state, null: false

      t.datetime :sent_at
      t.datetime :failed_at
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
