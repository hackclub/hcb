class AddSummaryPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :monthly_donation_summary, :boolean, default: true
    add_column :users, :monthly_follower_summary, :boolean, default: true
  end
end
