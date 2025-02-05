json.id card_grant.public_id
json.user card_grant.user, partial: "api/v4/users/user", as: :user if expand?(:user)
json.organization card_grant.event, partial: "api/v4/events/event", as: :event if expand?(:organization)
json.amount_cents card_grant.amount_cents
json.merchant_lock card_grant.merchant_lock
json.category_lock card_grant.category_lock
json.keyword_lock card_grant.keyword_lock
json.balance_cents card_grant.balance.cents if expand?(:balance_cents)
json.status card_grant.status
if expand?(:disbursements)
  json.disbursements card_grant.disbursements.order(created_at: :desc) do |disbursement|
    json.partial! "api/v4/transactions/disbursement", disbursement:
  end
end
json.card_id card_grant.stripe_card&.public_id
