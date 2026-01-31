# frozen_string_literal: true

json.id disbursement.public_id
json.memo disbursement.local_hcb_code.memo
json.status disbursement.v4_api_state
# `transaction_id` will eventually be deprecated
json.transaction_id disbursement.outgoing_hcb_code.public_id
json.outgoing_transaction_id disbursement.outgoing_hcb_code.public_id
json.incoming_transaction_id disbursement.incoming_hcb_code.public_id
json.amount_cents disbursement.amount

json.from do
  json.partial! "api/v4/events/event", event: disbursement.source_event
end

json.to do
  json.partial! "api/v4/events/event", event: disbursement.destination_event
end

json.sender do
  if disbursement.requested_by.present?
    json.partial! "api/v4/users/user", user: disbursement.requested_by
  else
    json.nil!
  end
end

if disbursement.card_grant.present?
  json.card_grant_id disbursement.card_grant&.public_id
end
