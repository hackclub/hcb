# frozen_string_literal: true

class CreateGrantsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :grants do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :sent_by, null: false, foreign_key: { to_table: :users }
      t.references :grantable, polymorphic: true, null: false, index: { unique: true }
      t.string :aasm_state, null: false, default: "pending"

      t.timestamps
    end
  end
end
