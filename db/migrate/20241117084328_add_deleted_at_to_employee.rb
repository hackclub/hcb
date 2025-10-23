class AddDeletedAtToEmployee < ActiveRecord::Migration[7.2]
  def change
    add_column :employees, :deleted_at, :datetime
  end
end
