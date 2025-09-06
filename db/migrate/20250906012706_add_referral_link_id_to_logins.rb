class AddReferralLinkIdToLogins < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :logins, :referral_link, index: {algorithm: :concurrently}
  end
end
