# frozen_string_literal: true

pagination_metadata(json)

expand :organization do
  json.data @hcb_codes, partial: "api/v4/transactions/transaction", as: :tx
end
