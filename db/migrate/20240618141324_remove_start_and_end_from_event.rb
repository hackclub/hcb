class RemoveStartAndEndFromEvent < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :events, :start }
    safety_assured { remove_column :events, :end }
  end
end
