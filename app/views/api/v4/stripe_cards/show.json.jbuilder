# frozen_string_literal: true

expand :user, :organization, :total_spent_cents do
  json.partial! @stripe_card
end
