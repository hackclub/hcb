# frozen_string_literal: true

json.array! @card_grants, partial: "api/v4/card_grants/card_grant", as: :card_grant, expand: [@event ? :user : :organization]
