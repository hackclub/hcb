# frozen_string_literal: true

module Column
  class SweepJob < ApplicationJob
    MINIMUM_AVG_BALANCE = 5_000_000_00 # 5 mil
    FLOATING_BALANCE = MINIMUM_AVG_BALANCE + 500_000_00 # 5.5 mil
    queue_as :low

    def perform
      account = ::ColumnService.get("/bank-accounts/#{ColumnService::Accounts::FS_MAIN}")
      balance = account["balances"]["available_amount"]

      return if balance >= FLOATING_BALANCE

      Rails.error.unexpected "Column available balance (#{ApplicationController.helpers.render_money(balance)}) is below threshold (#{ApplicationController.helpers.render_money(FLOATING_BALANCE)})"
    end

  end
end
