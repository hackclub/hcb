# frozen_string_literal: true

json.data @items, partial: "api/v5/transactions/transaction", as: :item
pagination_metadata(json)
