# frozen_string_literal: true

class AddFailedReminderTrackingToReimbursementPayoutHoldings < ActiveRecord::Migration[8.1]
  def change
    add_column :reimbursement_payout_holdings, :failed_at, :datetime
    add_column :reimbursement_payout_holdings, :failed_reminders_sent, :integer, default: 0, null: false
  end

end
