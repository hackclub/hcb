# frozen_string_literal: true

class AddPostDonationFieldsToEventConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_column :event_configurations, :post_donation_redirect_url, :string
    add_column :event_configurations, :post_donation_include_details, :boolean, default: false, null: false
  end
end
