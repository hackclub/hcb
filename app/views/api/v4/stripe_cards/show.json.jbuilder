# frozen_string_literal: true

expand :user, :organization, :total_spent_cents, :balance_available do
  json.partial! @stripe_card
end
