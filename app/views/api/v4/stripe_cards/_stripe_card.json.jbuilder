# frozen_string_literal: true

json.created_at stripe_card.created_at
json.id stripe_card.public_id
json.type stripe_card.card_type
json.status stripe_card.status_text.parameterize(separator: "_")
json.name stripe_card.name

if stripe_card.user == @current_user && stripe_card.initially_activated?
  json.last4 stripe_card.last4
  json.exp_month stripe_card.stripe_exp_month
  json.exp_year stripe_card.stripe_exp_year
else
  json.last4 nil
end

json.total_spent_cents stripe_card.total_spent if expand?(:total_spent_cents)

json.organization stripe_card.event, partial: "api/v4/events/event", as: :event if expand?(:organization)
json.user         stripe_card.user,  partial: "api/v4/users/user",   as: :user  if expand?(:user)
