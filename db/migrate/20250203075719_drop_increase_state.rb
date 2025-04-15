class DropIncreaseState < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :increase_checks, :increase_state }
  end
end
