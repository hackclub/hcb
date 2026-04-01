# frozen_string_literal: true

json.summary do
  json.total_cents @total_cents
  json.monthly_cents @monthly_cents
end

json.recurring_donations @recurring_donations do |rd|
  json.id rd.hashid
  json.status rd.stripe_status
  json.name rd.name(show_anonymous: false)
  json.email rd.email
  json.started_on rd.created_at.to_date
  json.amount_cents rd.amount
  json.total_donated_cents rd.total_donated
end

pagination_metadata(json)

json.past_donagio @past_donations do |donation|
  json.id donation.public_id
  json.status donation.aasm_state
  json.date donation.donated_at
  json.name donation.name
  json.email donation.email
  json.amount_cents donation.amount
  json.recurring donation.recurring?
  json.recurring_donor_id donation.recurring_donation&.hashid
end
