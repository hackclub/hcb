# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :event, null: false, foreign_key: true
      t.references :stripe_card, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :first_hcb_code, foreign_key: { to_table: :hcb_codes, on_delete: :nullify }
      t.string :name, null: false
      t.string :merchant_network_id
      t.string :merchant_name, null: false
      t.integer :amount_cents
      t.string :cadence, null: false
      t.integer :cadence_days, null: false
      t.string :source, null: false, default: "manual"
      t.string :status, null: false, default: "active"
      t.datetime :canceled_at
      t.datetime :last_charged_at
      t.datetime :next_expected_at

      t.timestamps
    end

    add_index :subscriptions, [:stripe_card_id, :merchant_network_id]
    add_index :subscriptions, [:event_id, :status]
  end

end
