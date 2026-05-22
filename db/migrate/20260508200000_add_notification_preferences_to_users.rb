class AddNotificationPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :donation_notifications, :boolean, default: true, null: false
    add_column :users, :invoice_notifications, :boolean, default: true, null: false
    add_column :users, :transfer_notifications, :boolean, default: true, null: false
    add_column :users, :reimbursement_notifications, :boolean, default: true, null: false
    add_column :users, :team_notifications, :boolean, default: true, null: false
    add_column :users, :card_grant_notifications, :boolean, default: true, null: false
  end
end
