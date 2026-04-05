# frozen_string_literal: true

json_object(json, wire)
json.organization_id wire.event.public_id
json.amount_cents wire.amount_cents
json.currency wire.currency
json.state wire.aasm_state
json.memo wire.memo
json.payment_for wire.payment_for

json.recipient_name wire.recipient_name
json.recipient_email wire.recipient_email
json.recipient_country wire.recipient_country

json.address_line1 wire.address_line1
json.address_line2 wire.address_line2
json.address_city wire.address_city
json.address_state wire.address_state
json.address_postal_code wire.address_postal_code

json.sender do
  json.partial! "api/v4/users/user", user: wire.user
end
