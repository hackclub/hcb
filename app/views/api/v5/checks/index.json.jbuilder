# frozen_string_literal: true

json.data @records, partial: "api/v5/transactions/check", as: :check
pagination_metadata(json)
