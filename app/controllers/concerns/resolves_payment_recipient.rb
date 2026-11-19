# frozen_string_literal: true

# Resolves the user-supplied `payment_recipient_id` form param (a hashid) to a
# real primary key, scoped to the current `@event`.

module ResolvesPaymentRecipient
  extend ActiveSupport::Concern

  private

  def scope_payment_recipient!(permitted)
    return permitted unless permitted.key?(:payment_recipient_id)

    hashid = permitted[:payment_recipient_id].presence
    recipient = hashid && @event.payment_recipients.find_by_hashid(hashid)
    authorize recipient, :show? if recipient
    permitted[:payment_recipient_id] = recipient&.id
    permitted
  end
end
