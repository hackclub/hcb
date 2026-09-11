# frozen_string_literal: true

# locals: (json:, disbursement:)

object_shape(json, disbursement) do |f|
  f.amount_cents disbursement.amount
  f.status disbursement.v4_api_state
  f.memo { disbursement.local_hcb_code.memo }

  f.transaction_id { disbursement.outgoing_disbursement.local_hcb_code.public_id }
  f.outgoing_transaction_id { disbursement.outgoing_disbursement.local_hcb_code.public_id }
  f.incoming_transaction_id { disbursement.incoming_disbursement.local_hcb_code.public_id }
  f.card_grant_id { disbursement.card_grant&.public_id }

  f.nest(:from) { json.partial! "api/v5/events/event", event: disbursement.source_event }
  f.nest(:to)   { json.partial! "api/v5/events/event", event: disbursement.destination_event }

  f.nest(:sender) do
    if disbursement.requested_by.present?
      json.partial! "api/v5/users/user", user: disbursement.requested_by
    else
      json.nil!
    end
  end
end
