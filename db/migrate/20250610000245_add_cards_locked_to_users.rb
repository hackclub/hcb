class AddCardsLockedToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :cards_locked, :boolean, null: false, default: false
  end
end
