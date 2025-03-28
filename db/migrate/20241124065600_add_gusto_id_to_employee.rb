class AddGustoIdToEmployee < ActiveRecord::Migration[7.2]
  def change
    add_column :employees, :gusto_id, :string
  end
end
