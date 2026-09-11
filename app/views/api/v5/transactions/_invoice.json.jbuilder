# frozen_string_literal: true

# locals: (json:, invoice:)

object_shape(json, invoice) do |f|
  f.amount_cents invoice.item_amount
  f.status invoice.status
  f.sent_at invoice.created_at
  f.paid_at invoice.paid_at
  f.description invoice.item_description
  f.due_date { invoice.due_date&.to_date }

  f.nest(:sponsor) do
    json.id invoice.sponsor.public_id
    json.name invoice.sponsor.name
  end
  f.sponsor_email { invoice.sponsor.contact_email }
end
