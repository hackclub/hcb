# frozen_string_literal: true

json.data @receipts, partial: "api/v5/receipts/receipt", as: :receipt
pagination_metadata(json)
