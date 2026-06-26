# frozen_string_literal: true

class AddDonationPayoutReferencesToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_reference :transact_so_ns, :donation_payout, foreign_key: true
  end

end
