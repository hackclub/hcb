# frozen_string_literal: true

class CreateLedgers < ActiveRecord::Migration[8.0]
  def change
    create_table :ledgers do |t|
      # Primary means it's on a ledger that modifies balances
      t.boolean :primary, null: false

      # Owners for primary ledger
      t.references :event, null: true, foreign_key: true
      t.references :card_grant, null: true, foreign_key: true

      t.timestamps
    end

    add_check_constraint :ledgers,
                         <<~SQL.squish,
                           (\"primary\" IS TRUE AND (
                             (event_id IS NOT NULL AND card_grant_id IS NULL) OR
                             (event_id IS NULL AND card_grant_id IS NOT NULL)
                           )) OR
                           (\"primary\" IS FALSE AND event_id IS NULL AND card_grant_id IS NULL)
                         SQL
                         name: "ledgers_owner_rules",
                         validate: false
  end

end
