# frozen_string_literal: true

if expand?(:stats)
  json.stats do
    json.total_cents @total_cents
    json.monthly_cents @monthly_cents
  end
end

pagination_metadata(json)

json.data @past_donations do |donation|
  json.partial! "api/v4/transactions/donation", donation: donation
end
