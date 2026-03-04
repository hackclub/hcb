# frozen_string_literal: true

json.array! @balance_series do |point|
  json.date point[:date]
  json.amount point[:amount]
end
