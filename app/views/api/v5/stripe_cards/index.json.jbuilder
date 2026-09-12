# frozen_string_literal: true

json.data @records, partial: "api/v5/stripe_cards/stripe_card", as: :stripe_card
pagination_metadata(json)
