# frozen_string_literal: true

json.data @records, partial: "api/v5/transactions/wire_transfer", as: :wire_transfer
pagination_metadata(json)
