# frozen_string_literal: true

json.created_at stripe_card.created_at
json.id stripe_card.public_id
json.type stripe_card.card_type
json.status stripe_card.status_text.parameterize(separator: "_")
json.name stripe_card.name

if stripe_card.initially_activated?
  json.last4 stripe_card.last4
  json.exp_month stripe_card.stripe_exp_month
  json.exp_year stripe_card.stripe_exp_year
else
  json.last4 nil
end

json.total_spent_cents stripe_card.total_spent if expand?(:total_spent_cents)
json.balance_available stripe_card.balance_available if expand?(:balance_available)

json.organization stripe_card.event, partial: "api/v4/events/event", as: :event if expand?(:organization)
json.user         stripe_card.user,  partial: "api/v4/users/user",   as: :user  if expand?(:user)
json.last_frozen_by stripe_card.last_frozen_by, partial: "api/v4/users/user", as: :user if expand?(:last_frozen_by)

if stripe_card.physical?
  json.personalization do
    json.color stripe_card.personalization_design.color
    json.logo_url rails_blob_url(stripe_card.personalization_design.logo)
  end
  json.shipping if policy(stripe_card).shipping? do
    json.status stripe_card.remote_shipping_status
    json.eta stripe_card.shipping_eta
    json.address do
      json.line1 stripe_card.stripe_shipping_address_line1
      json.line2 stripe_card.stripe_shipping_address_line2
      json.city stripe_card.stripe_shipping_address_city
      json.state stripe_card.stripe_shipping_address_state
      json.country stripe_card.stripe_shipping_address_country
      json.postal_code stripe_card.stripe_shipping_address_postal_code
    end
  end
end
