# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :event, null: false, foreign_key: true
      t.references :stripe_card, null: false, foreign_key: true
      t.string :merchant_network_id
      t.string :merchant_name, null: false
      t.integer :amount_cents, null: false
      t.string :cadence, null: false
      t.integer :cadence_days, null: false
      t.datetime :last_charged_at
      t.datetime :next_expected_at

      t.timestamps
    end

    add_index :subscriptions, [:stripe_card_id, :merchant_network_id]
  end

end
