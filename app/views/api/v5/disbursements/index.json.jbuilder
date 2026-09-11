# frozen_string_literal: true

json.data @records, partial: "api/v5/transactions/disbursement", as: :disbursement
pagination_metadata(json)
