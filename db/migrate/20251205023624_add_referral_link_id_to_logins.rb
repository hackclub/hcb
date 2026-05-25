class AddReferralLinkIdToLogins < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :logins, :referral_link, index: { algorithm: :concurrently }
  end
end
