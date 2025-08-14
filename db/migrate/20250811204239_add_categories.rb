# frozen_string_literal: true

class AddCategories < ActiveRecord::Migration[7.2]
  def change
    create_table(:transaction_categories) do |t|
      t.column(:name, :citext, null: false)
      t.timestamps

      t.index(:name, unique: true)
    end

    create_table(:canonical_pending_transaction_categories) do |t|
      t.references(:transaction_category, null: false, foreign_key: true)
      t.references(:canonical_pending_transaction, null: false, foreign_key: true, index: { unique: true})
      t.text(:assignment_strategy, null: false)
      t.timestamps
    end

    create_table(:canonical_transaction_categories) do |t|
      t.references(:transaction_category, null: false, foreign_key: true)
      t.references(:canonical_transaction, null: false, foreign_key: true, index: {unique: true})
      t.text(:assignment_strategy, null: false)
      t.timestamps
    end
  end
end
