class AddSortIndexToCardGrants < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grants, :sort_index, :float
  end
end
