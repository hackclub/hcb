json.id disbursement.public_id
json.memo disbursement.local_hcb_code.memo
json.status disbursement.v4_api_state
json.transaction_id disbursement.local_hcb_code.public_id
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
