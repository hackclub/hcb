class AddDeletedToTotp < ActiveRecord::Migration[7.1]
  def change
    add_column :user_totps, :deleted_at, :datetime
  end
end
