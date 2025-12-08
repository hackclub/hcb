class AddReferralLinkForeignKeyToReferralAttributions < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :referral_attributions, :referral_links, column: :referral_link_id, validate: false
  end
end
