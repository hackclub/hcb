# frozen_string_literal: true

pagination_metadata(json)

json.data @recurring_donations do |recurring_donation|
  json.partial! "api/v4/recurring_donations/recurring_donation", recurring_donation: recurring_donation
end
