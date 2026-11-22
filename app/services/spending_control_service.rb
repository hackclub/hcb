# frozen_string_literal: true

module SpendingControlService
  def self.check_low_balance(spending_control, ledger_item_id:, balance_change_cents:)
    return unless balance_change_cents.negative? && spending_control.transactions.exists?(ledger_item_id)

    balance = spending_control.balance_cents
    previous_balance = balance - balance_change_cents

    # These emails could get repetitive quickly if a user has a low spending balance and is only spending small amounts
    # So the $25 threshold is only taken into account when crossed for the first time
    if (previous_balance > 25_00 && balance <= 25_00) || balance <= previous_balance / 10
      OrganizerPosition::Spending::ControlsMailer.with(control: spending_control).low_balance_warning.deliver_later
    end
  end
end
