class DropOmitStatsFromEvent < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :events, :omit_stats }
  end
end
