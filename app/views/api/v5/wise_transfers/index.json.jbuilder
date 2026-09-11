# frozen_string_literal: true

json.data @records, partial: "api/v5/transactions/wise_transfer", as: :wise_transfer
pagination_metadata(json)
