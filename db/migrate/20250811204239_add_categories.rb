# frozen_string_literal: true

class AddCategories < ActiveRecord::Migration[7.2]
  def change
    create_table(:transaction_categories) do |t|
      t.column(:slug, :citext, null: false)
      t.timestamps

      t.index(:slug, unique: true)
    end

    create_table(:transaction_category_mappings) do |t|
      t.references(:transaction_category, null: false, foreign_key: true)
      t.text(:categorizable_type, null: false)
      t.bigint(:categorizable_id, null: false)
      t.text(:assignment_strategy, null: false)
      t.timestamps

      t.index([:categorizable_type, :categorizable_id], unique: true)
    end
  end
end
