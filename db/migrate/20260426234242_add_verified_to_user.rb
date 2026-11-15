class AddVerifiedToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :verified, :boolean, default: true, null: false
    change_column_default :users, :verified, from: true, to: false
  end
end
