# frozen_string_literal: true

json.id invoice.public_id
json.amount_cents invoice.item_amount
json.sent_at invoice.created_at
json.paid_at invoice.paid_at
json.description invoice.item_description
json.due_date invoice.due_date.to_date
json.sponsor do
  json.id invoice.sponsor.public_id
  json.name invoice.sponsor.name
  json.email invoice.sponsor.contact_email if policy(invoice.local_hcb_code).show?
end
