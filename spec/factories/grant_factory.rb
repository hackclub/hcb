# frozen_string_literal: true

FactoryBot.define do
  # A CardGrant creates its Grant on create, and the grantable is unique, so the
  # factory returns that grant rather than building a second one. Defaults to a
  # pending invitation; drive it through the card grant for other states.
  factory :grant do
    initialize_with { create(:card_grant, :pending_invite).grant }
  end
end
