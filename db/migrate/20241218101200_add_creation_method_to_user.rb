class AddCreationMethodToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :creation_method, :int
  end
end
