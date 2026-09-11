# frozen_string_literal: true

# locals: (json:, expense_payout:)

object_shape(json, expense_payout) do |f|
  f.amount_cents expense_payout.amount
end
