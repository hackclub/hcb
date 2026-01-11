# frozen_string_literal: true

module Column
  class OperatingBalanceJob < ApplicationJob
    queue_as :low

    def perform
      account = ::ColumnService.get("/bank-accounts/#{ColumnService::Accounts::FS_OPERATING}")
      balance = account["balances"]["available_amount"]

      if balance != 0
        Rails.error.unexpected "FS Operating has a non-zero available balance (#{ApplicationController.helpers.render_money(balance)})"
      end

    end

  end
end
