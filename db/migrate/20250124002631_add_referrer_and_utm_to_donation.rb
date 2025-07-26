class AddReferrerAndUtmToDonation < ActiveRecord::Migration[7.2]
  def change
    add_column :donations, :referrer, :text
    add_column :donations, :utm_source, :text
    add_column :donations, :utm_medium, :text
    add_column :donations, :utm_campaign, :text
    add_column :donations, :utm_term, :text
    add_column :donations, :utm_content, :text
  end
end
