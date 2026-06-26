# frozen_string_literal: true

pagination_metadata(json)

json.data @transact_so_ns, partial: "api/v4/transactions/transaction", as: :tx
