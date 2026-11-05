# frozen_string_literal: true

class AddRetryDetailsToReimbursementPayoutHoldings < ActiveRecord::Migration[8.1]
  def change
    add_column :reimbursement_payout_holdings, :failure_reason, :string
    add_column :reimbursement_payout_holdings, :retry_at, :datetime
  end

end
