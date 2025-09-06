class AddReferralLinkForeignKeyToLogins < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :logins, :referral_links, column: :referral_link_id, validate: false
  end
end
