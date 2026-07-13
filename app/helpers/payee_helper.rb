# frozen_string_literal: true

module PayeeHelper
  # Routes a selected payee to the right "new transfer" flow, shared between the
  # contractors and payments recipient pickers.
  def new_recipient_transfer_path(destination, event, **opts)
    if destination.to_s == "contractors"
      new_event_payroll_position_path(event_id: event.slug, **opts)
    else
      new_event_payment_path(event_id: event.slug, **opts)
    end
  end
end
