# frozen_string_literal: true

json.id wise_transfer.public_id

json.recipient_name wise_transfer.recipient_name
json.recipient_email wise_transfer.recipient_email
json.recipient_country wise_transfer.recipient_country

json.payment_for wise_transfer.payment_for
json.currency wise_transfer.currency
json.amount_cents wise_transfer.amount_cents
json.usd_amount_cents wise_transfer.usd_amount_cents if wise_transfer.usd_amount_cents.present?
json.state wise_transfer.aasm_state
json.organization_id wise_transfer.event_id

json.return_reason wise_transfer.return_reason if wise_transfer.return_reason.present?

json.sent_at wise_transfer.sent_at if wise_transfer.sent_at.present?
json.created_at wise_transfer.created_at

json.sender do
  if wise_transfer.user.present?
    json.partial! "api/v4/users/user", user: wise_transfer.user
  else
    json.nil!
  end
end
