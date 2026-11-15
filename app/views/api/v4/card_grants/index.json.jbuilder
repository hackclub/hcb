# frozen_string_literal: true

expand @event ? :user : :organization do
  json.array! @card_grants, partial: "api/v4/card_grants/card_grant", as: :card_grant
end
