# frozen_string_literal: true

module FeeRevenueService
  class ProcessSingle
    def initialize(fee_revenue_id:)
      @fee_revenue_id = fee_revenue_id
    end

    def run
      raise ArgumentError, "must be pending fee revenue only" unless fee_revenue.pending?

      ActiveRecord::Base.transaction do
        fee_revenue.mark_in_transit!

        sender_bank_account_id = ColumnService::Accounts.id_of fee_revenue.book_transfer_originating_account
        receiver_bank_account_id = ColumnService::Accounts.id_of fee_revenue.book_transfer_receiving_account

        ColumnService.post "/transfers/book",
                           idempotency_key: fee_revenue.public_id,
                           amount: amount_cents.abs,
                           currency_code: "USD",
                           sender_bank_account_id:,
                           receiver_bank_account_id:,
                           description: fee_revenue.short_code_memo
      end

      true
    end

    private

    def amount_cents
      fee_revenue.amount_cents
    end

    def fee_revenue
      @fee_revenue ||= FeeRevenue.pending.find(@fee_revenue_id)
    end

  end
end
