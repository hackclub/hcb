# frozen_string_literal: true

json.array! @checks, partial: "api/v4/transactions/check", as: :check
