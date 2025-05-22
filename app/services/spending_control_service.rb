# frozen_string_literal: true

module SpendingControlService
  def self.check_low_balance(spending_control, amount_difference)
    historic_max_balance_cents = (spending_control.balance_cents - amount_difference) / 10
    threshold = [historic_max_balance_cents, 25_00].max

    if spending_control.balance_cents <= threshold
      OrganizerPosition::Spending::ControlsMailer.with(control: spending_control).warning.deliver_later
    end

  end
end
