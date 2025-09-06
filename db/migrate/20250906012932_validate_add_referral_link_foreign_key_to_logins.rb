class ValidateAddReferralLinkForeignKeyToLogins < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :logins, :referral_links
  end
end
