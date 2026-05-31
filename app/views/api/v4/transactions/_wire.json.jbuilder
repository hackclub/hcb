# frozen_string_literal: true

# locals: (json:, wire:)

object_shape(json, wire) do
  json.recipient_name wire.recipient_name
  json.recipient_email wire.recipient_email
  json.amount_cents wire.usd_amount_cents
  json.currency wire.currency
  json.memo wire.memo
  json.payment_for wire.payment_for
  json.status wire.aasm_state

  json.sender do
    if wire.user.present?
      json.partial! "api/v4/users/user", user: wire.user
    else
      json.nil!
    end
  end
end
