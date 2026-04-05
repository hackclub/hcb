# frozen_string_literal: true

json.array! @receipts, partial: "api/v4/receipts/receipt", as: :receipt
