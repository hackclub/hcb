# frozen_string_literal: true

json.data @records, partial: "api/v5/transactions/check_deposit", as: :check_deposit
pagination_metadata(json)
