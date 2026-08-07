class AddStateToLogin < ActiveRecord::Migration[8.0]
  def change
    add_column :logins, :state, :jsonb
  end
end
