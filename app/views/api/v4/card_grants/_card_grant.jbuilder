json.id card_grant.public_id
json.user card_grant.user, partial: "api/v4/users/user", as: :user if local_assigns[:expand]&.include?(:user)
json.organization card_grant.event, partial: "api/v4/events/event", as: :event if local_assigns[:expand]&.include?(:organization)
json.amount_cents card_grant.amount_cents
json.merchant_lock card_grant.merchant_lock
json.category_lock card_grant.category_lock
