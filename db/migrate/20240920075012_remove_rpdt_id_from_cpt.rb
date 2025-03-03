class RemoveRpdtIdFromCpt < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :canonical_pending_transactions, :raw_pending_partner_donation_transaction_id
    end
  end
end
