# frozen_string_literal: true

json.array! @categories do |category|
  json.slug category.slug
  json.label category.label
  json.payment_selectable @payment_selectable.key?(category.slug)
end
