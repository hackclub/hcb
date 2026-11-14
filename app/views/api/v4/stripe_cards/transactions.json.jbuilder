# frozen_string_literal: true

pagination_metadata(json)

json.data @transactions do |tx|
  if tx.is_a?(HcbCode) && tx.canonical_transactions.none?
    json.partial! "api/v4/transactions/transaction", tx: tx.pt
  else
    json.partial! "api/v4/transactions/transaction", tx:
  end
end
