# frozen_string_literal: true

json.id wire_transfer.public_id
json.organization_id wire_transfer.event.public_id
json.amount_cents wire_transfer.amount_cents
json.currency wire_transfer.currency
json.state wire_transfer.aasm_state
json.memo wire_transfer.memo
json.payment_for wire_transfer.payment_for

json.recipient_name wire_transfer.recipient_name
json.recipient_email wire_transfer.recipient_email
json.recipient_country wire_transfer.recipient_country

json.address_line1 wire_transfer.address_line1
json.address_line2 wire_transfer.address_line2
json.address_city wire_transfer.address_city
json.address_state wire_transfer.address_state
json.address_postal_code wire_transfer.address_postal_code

json.created_at wire_transfer.created_at

json.sender do
  json.partial! "api/v4/users/user", user: wire_transfer.user
end