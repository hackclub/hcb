# frozen_string_literal: true

# locals: (json:, paypal_transfer:)

object_shape(json, paypal_transfer) do
  json.recipient_name paypal_transfer.recipient_name
  json.recipient_email paypal_transfer.recipient_email
  json.amount_cents paypal_transfer.amount_cents
  json.memo paypal_transfer.memo
  json.payment_for paypal_transfer.payment_for
  json.status paypal_transfer.aasm_state

  json.sender do
    if paypal_transfer.user.present?
      json.partial! "api/v4/users/user", user: paypal_transfer.user
    else
      json.nil!
    end
  end
end
