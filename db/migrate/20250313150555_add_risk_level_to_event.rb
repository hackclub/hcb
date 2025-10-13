class AddRiskLevelToEvent < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :risk_level, :int
  end
end
