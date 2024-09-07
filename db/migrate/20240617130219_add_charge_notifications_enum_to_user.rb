class AddChargeNotificationsEnumToUser < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :charge_notifications, :integer, null: false, default: 0
  end
end
