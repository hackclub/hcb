# frozen_string_literal: true

module SpendingControlService
  def self.check_low_balance(spending_control, hcb_code)
    difference = 0
    if hcb_code.canonical_transactions.empty?
      difference = hcb_code.amount_cents
    elsif hcb_code.canonical_transactions.size == 1
      ct = hcb_code.canonical_transactions.first
      cpt = hcb_code.canonical_pending_transactions.first
      difference = ct.amount_cents - cpt.amount_cents
    else
      difference = hcb_code.canonical_transactions.first.amount_cents
    end

    previous_balance = spending_control.balance_cents - difference

    # These emails could get repetitive quickly if a user has a low spending balance and is only spending small amounts
    # So the $25 threshold is only taken into account when crossed for the first time
    if (previous_balance > 25_00 && spending_control.balance_cents <= 25_00) || spending_control.balance_cents <= previous_balance / 10
      OrganizerPosition::Spending::ControlsMailer.with(control: spending_control).low_balance_warning.deliver_later
    end
  end
end
