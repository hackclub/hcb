# frozen_string_literal: true

# locals: (json:, wise_transfer:)

object_shape(json, wise_transfer) do |f|
  f.amount_cents wise_transfer.amount_cents
  f.usd_amount_cents wise_transfer.usd_amount_cents
  f.currency wise_transfer.currency
  f.state wise_transfer.aasm_state
  f.organization_id wise_transfer.event.public_id
  f.recipient_name wise_transfer.recipient_name
  f.recipient_email wise_transfer.recipient_email
  f.recipient_country wise_transfer.recipient_country
  f.payment_for wise_transfer.payment_for
  f.return_reason wise_transfer.return_reason
  f.sent_at wise_transfer.sent_at

  f.nest(:sender) do
    if wise_transfer.user.present?
      json.partial! "api/v5/users/user", user: wise_transfer.user
    else
      json.nil!
    end
  end
end
