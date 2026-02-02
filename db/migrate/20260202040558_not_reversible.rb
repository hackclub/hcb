class NotReversible < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :announcements, :title }
  end
end
