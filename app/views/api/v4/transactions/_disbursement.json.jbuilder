# frozen_string_literal: true

object_shape(json, disbursement) do
  json.memo disbursement.local_hcb_code.memo
  json.status disbursement.v4_api_state

  outgoing_hcb_code = disbursement.outgoing_disbursement.local_hcb_code
  incoming_hcb_code = disbursement.incoming_disbursement.local_hcb_code

  # `transaction_id` will eventually be deprecated
  json.transaction_id outgoing_hcb_code.public_id
  json.outgoing_transaction_id outgoing_hcb_code.public_id
  json.incoming_transaction_id incoming_hcb_code.public_id
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
end
