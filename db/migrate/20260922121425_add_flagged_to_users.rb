# frozen_string_literal: true

class AddFlaggedToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    safety_assured do
      change_table :users, bulk: true do |t|
        t.datetime :flagged_at
        t.text :flagged_reason
        t.bigint :flagged_by_id
      end
    end

    add_index :users, :flagged_by_id, algorithm: :concurrently
    add_index :users, :flagged_at, algorithm: :concurrently, where: "flagged_at IS NOT NULL"

    add_foreign_key :users, :users, column: :flagged_by_id, validate: false
  end

end
