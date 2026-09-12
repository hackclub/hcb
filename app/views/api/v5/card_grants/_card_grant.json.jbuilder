# frozen_string_literal: true

# locals: (json:, card_grant:)

object_shape(json, card_grant) do |f|
  f.amount_cents card_grant.amount_cents
  f.status card_grant.status
  f.purpose card_grant.purpose
  f.email card_grant.email
  f.expires_on card_grant.expiration_at
  f.card_id { card_grant.stripe_card&.public_id }
  f.merchant_lock card_grant.merchant_lock
  f.category_lock card_grant.category_lock
  f.keyword_lock card_grant.keyword_lock
  f.allowed_merchants card_grant.allowed_merchants
  f.allowed_categories card_grant.allowed_categories
  f.one_time_use card_grant.one_time_use
  f.pre_authorization_required card_grant.pre_authorization_required
  f.balance_cents { card_grant.balance.cents } if expand?(:balance_cents)

  expand_association(f, json, :user,         card_grant.user,  partial: "api/v5/users/user",   as: :user)
  expand_association(f, json, :organization, card_grant.event, partial: "api/v5/events/event", as: :event)
end
