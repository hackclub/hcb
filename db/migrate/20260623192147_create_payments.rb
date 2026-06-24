class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.string :aasm_state, null: false
      t.datetime :under_review_at
      t.datetime :sent_at
      t.datetime :rejected_at
      t.datetime :failed_at
      t.datetime :successful_at

      t.string :purpose, null: false
      t.integer :amount_cents, null: false

      t.belongs_to :payout, polymorphic: true

      t.timestamps
    end
  end
end
