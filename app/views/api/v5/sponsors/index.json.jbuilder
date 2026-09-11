# frozen_string_literal: true

json.data @sponsors, partial: "api/v5/sponsors/sponsor", as: :sponsor
pagination_metadata(json)
