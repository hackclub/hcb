class CreateWires < ActiveRecord::Migration[7.1]
  def change
    create_table :wires do |t|
      t.string :memo, null: false
      t.string :payment_for, null: false
      t.integer :amount_cents, null: false
      t.string :recipient_name, null: false
      t.string :recipient_email, null: false
      t.string :account_number_ciphertext, null: false
      t.string :account_number_bidx, null: false
      t.string :bic_code_ciphertext, null: false
      t.string :bic_code_bidx, null: false
      t.string :aasm_state, null: false
      t.datetime :approved_at
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
    
      t.timestamps
    end
  end
end
