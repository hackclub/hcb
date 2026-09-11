# frozen_string_literal: true

# locals: (json:, wire_transfer:)

object_shape(json, wire_transfer) do |f|
  f.amount_cents wire_transfer.amount_cents
  f.usd_amount_cents { wire_transfer.try(:usd_amount_cents) }
  f.currency wire_transfer.currency
  f.state wire_transfer.aasm_state
  f.organization_id wire_transfer.event.public_id
  f.memo wire_transfer.memo
  f.payment_for wire_transfer.payment_for
  f.recipient_name wire_transfer.recipient_name
  f.recipient_email wire_transfer.recipient_email
  f.recipient_country wire_transfer.recipient_country
  f.address_line1 wire_transfer.address_line1
  f.address_line2 wire_transfer.address_line2
  f.address_city wire_transfer.address_city
  f.address_state wire_transfer.address_state
  f.address_postal_code wire_transfer.address_postal_code

  f.nest(:sender) do
    if wire_transfer.user.present?
      json.partial! "api/v5/users/user", user: wire_transfer.user
    else
      json.nil!
    end
  end
end
