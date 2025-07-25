# frozen_string_literal: true

class ChangeFlipperGatesValueToText < ActiveRecord::Migration[7.2]
  def up
    # Ensure this incremental update migration is idempotent
    return unless connection.column_exists? :flipper_gates, :value, :string

    if index_exists? :flipper_gates, [:feature_key, :key, :value]
      remove_index :flipper_gates, [:feature_key, :key, :value]
    end
    change_column :flipper_gates, :value, :text
    safety_assured do
      add_index :flipper_gates, [:feature_key, :key, :value], unique: true, length: { value: 255 }
    end
  end

  def down
    change_column :flipper_gates, :value, :string
  end
end
