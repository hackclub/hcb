# frozen_string_literal: true

# locals: (json:, wire_transfer:)

object_shape(json, wire_transfer) do
  json.recipient_name wire_transfer.recipient_name
  json.recipient_email wire_transfer.recipient_email
  json.recipient_country wire_transfer.recipient_country

  json.payment_for wire_transfer.payment_for
  json.currency wire_transfer.currency
  json.amount_cents wire_transfer.amount_cents
  json.usd_amount_cents wire_transfer.usd_amount_cents if wire_transfer.usd_amount_cents.present?
  json.state wire_transfer.aasm_state
  json.organization_id wire_transfer.event_id

  json.return_reason wire_transfer.return_reason if wire_transfer.return_reason.present?

  json.approved_at wire_transfer.approved_at if wire_transfer.approved_at.present?

  json.sender do
    if wire_transfer.user.present?
      json.partial! "api/v4/users/user", user: wire_transfer.user
    else
      json.nil!
    end
  end
end
