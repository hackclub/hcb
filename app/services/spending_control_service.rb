# frozen_string_literal: true

module SpendingControlService
  def self.check_low_balance(spending_control, amount_difference)
    historic_max_balance_cents = spending_control.balance_cents - amount_difference

    # These emails could get repetitive quickly if a user has a low spending balance and is only spending small amounts
    # So the $25 threshold is only taken into account when crossed for the first time
    if (historic_max_balance_cents > 25_00 && spending_control.balance_cents <= 25_00) || spending_control.balance_cents <= historic_max_balance_cents / 10
      OrganizerPosition::Spending::ControlsMailer.with(control: spending_control).low_balance_warning.deliver_later
    end
  end
end
