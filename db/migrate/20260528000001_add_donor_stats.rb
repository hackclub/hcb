class AddDonorStats < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :show_top_donors, :boolean, default: false, null: false
    add_column :events, :show_recent_donors, :boolean, default: false, null: false
  end
end
