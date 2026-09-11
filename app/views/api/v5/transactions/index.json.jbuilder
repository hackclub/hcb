# frozen_string_literal: true

json.data @transactions, partial: "api/v5/transactions/transaction", as: :tx
pagination_metadata(json)
