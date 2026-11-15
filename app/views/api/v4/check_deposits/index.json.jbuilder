# frozen_string_literal: true

json.array! @check_deposits, partial: "api/v4/check_deposits/check_deposit", as: :check_deposit
