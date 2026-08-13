class AddSensitiveToAhoyMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :ahoy_messages, :sensitive, :boolean, default: false, null: false
  end
end
