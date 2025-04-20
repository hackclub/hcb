# frozen_string_literal: true

class AddDonationSummarySettingToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :donation_summary_option, :integer, default: 1, null: false
  end
  
end
