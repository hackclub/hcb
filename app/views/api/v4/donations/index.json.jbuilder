# frozen_string_literal: true

if expand?(:stats)
  json.stats do
    json.total_cents @total_cents
    json.monthly_cents @monthly_cents
  end
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

json.data @past_donations do |donation|
  json.partial! "api/v4/transactions/donation", donation: donation
end
