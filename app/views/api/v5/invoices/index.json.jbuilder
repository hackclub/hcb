# frozen_string_literal: true

json.data @records, partial: "api/v5/transactions/invoice", as: :invoice
pagination_metadata(json)
