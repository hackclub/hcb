# frozen_string_literal: true

class RemoveDemoModeFromEvents < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :events, :demo_mode, :boolean, default: false, null: false }
  end
end
