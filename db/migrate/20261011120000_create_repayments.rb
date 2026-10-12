# frozen_string_literal: true

class CreateRepayments < ActiveRecord::Migration[8.1]
  def change
    create_table :repayments do |t|
      t.references :disbursement, null: false, foreign_key: true
      t.references :hcb_code, null: false, foreign_key: true
      t.integer :amount_cents, null: false

      t.timestamps
    end

    add_index :repayments, [:disbursement_id, :hcb_code_id], unique: true
  end

end
