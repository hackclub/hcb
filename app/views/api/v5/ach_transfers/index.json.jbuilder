# frozen_string_literal: true

json.data @records, partial: "api/v5/transactions/ach_transfer", as: :ach_transfer
pagination_metadata(json)
