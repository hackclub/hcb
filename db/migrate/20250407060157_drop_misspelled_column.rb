class DropMisspelledColumn < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :events, :finanically_frozen
    end
  end
end
