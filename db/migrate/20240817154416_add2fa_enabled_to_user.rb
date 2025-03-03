class Add2faEnabledToUser < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :use_two_factor_authentication, :boolean, default: false
  end
end
