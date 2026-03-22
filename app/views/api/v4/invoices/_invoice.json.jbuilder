# frozen_string_literal: true

json.id invoice.public_id
json.status invoice.state_text
json.created_at invoice.created_at
json.to invoice.sponsor.name
json.amount_due invoice.amount_due
if policy(invoice).show_in_v4?
  json.memo invoice.memo
  json.due_date invoice.due_date
  json.item_amount invoice.item_amount
  json.item_description invoice.item_description
  json.sponsor_id invoice.sponsor_id
end
