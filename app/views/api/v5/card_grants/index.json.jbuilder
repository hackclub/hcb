# frozen_string_literal: true

json.data @records, partial: "api/v5/card_grants/card_grant", as: :card_grant
pagination_metadata(json)
