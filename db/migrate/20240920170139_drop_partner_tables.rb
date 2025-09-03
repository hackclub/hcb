class DropPartnerTables < ActiveRecord::Migration[7.2]
  def change
    drop_table :login_tokens
    drop_table :partner_donations
    drop_table :partnered_signups
    drop_table :partners
    drop_table :raw_pending_partner_donation_transactions
  end
end
