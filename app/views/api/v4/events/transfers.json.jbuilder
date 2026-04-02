# frozen_string_literal: true

json.stats do
  json.deposited_cents @stats[:deposited]
  json.in_transit_cents @stats[:in_transit]
  json.canceled_cents @stats[:canceled]
end

pagination_metadata(json)

json.data @transfers do |transfer|
  json.id transfer.public_id
  json.created_at transfer.created_at

  case transfer
  when AchTransfer
    json.type "ach_transfer"
    json.status transfer.aasm_state
    json.recipient_name transfer.recipient_name
    json.recipient_email transfer.recipient_email
    json.payment_for transfer.payment_for
    json.amount_cents transfer.amount
  when IncreaseCheck
    json.type "check"
    json.status transfer.state_text.parameterize(separator: "_")
    json.recipient_name transfer.recipient_name
    json.recipient_email transfer.recipient_email
    json.payment_for transfer.payment_for
    json.amount_cents transfer.amount
  when Check
    json.type "check"
    json.status nil
    json.recipient_name transfer.recipient_name
    json.recipient_email nil
    json.payment_for transfer.payment_for
    json.amount_cents transfer.amount
  when Disbursement
    json.type "disbursement"
    json.status transfer.v4_api_state
    json.recipient_name transfer.destination_event.name
    json.recipient_email nil
    json.payment_for transfer.name
    json.amount_cents transfer.amount
    json.destination_organization do
      json.partial! "api/v4/events/event", event: transfer.destination_event
    end
  when PaypalTransfer
    json.type "paypal_transfer"
    json.status transfer.aasm_state
    json.recipient_name transfer.recipient_name
    json.recipient_email transfer.recipient_email
    json.payment_for transfer.payment_for
    json.amount_cents transfer.amount_cents
  when Wire
    json.type "wire"
    json.status transfer.aasm_state
    json.recipient_name transfer.recipient_name
    json.recipient_email transfer.recipient_email
    json.payment_for transfer.payment_for
    json.amount_cents transfer.usd_amount_cents || transfer.amount_cents
    json.local_currency transfer.currency
    json.local_amount_cents transfer.amount_cents
  when WiseTransfer
    json.type "wise_transfer"
    json.status transfer.aasm_state
    json.recipient_name transfer.recipient_name
    json.recipient_email transfer.recipient_email
    json.payment_for transfer.payment_for
    json.amount_cents transfer.usd_amount_cents_or_quoted
    json.local_currency transfer.currency
    json.local_amount_cents transfer.amount_cents
  end
end
