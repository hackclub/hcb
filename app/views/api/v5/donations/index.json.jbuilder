# frozen_string_literal: true

json.data @records, partial: "api/v5/transactions/donation", as: :donation
pagination_metadata(json)
