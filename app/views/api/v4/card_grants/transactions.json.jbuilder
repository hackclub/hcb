# frozen_string_literal: true

pagination_metadata(json)

json.data @hcb_codes do |hcb_code|
  if hcb_code.canonical_transactions.any?
    json.partial! "api/v4/transactions/transaction", tx: hcb_code
  else
    json.partial! "api/v4/transactions/transaction", tx: hcb_code.pt
  end
end
