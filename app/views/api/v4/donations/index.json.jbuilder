# frozen_string_literal: true

if expand?(:stats)
  json.stats do
    json.total_cents @total_cents
  end
end

pagination_metadata(json)

json.data @donations do |donation|
  json.partial! "api/v4/transactions/donation", donation: donation
end
