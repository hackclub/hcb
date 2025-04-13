# frozen_string_literal: true

module Reimbursement
  module PayoutHoldingService
    class ProcessSingle
      def initialize(payout_holding_id:)
        @payout_holding_id = payout_holding_id
      end

      def run
        raise ArgumentError, "must be pending payout holding only" unless payout_holding.pending?

        ActiveRecord::Base.transaction do
          payout_holding.mark_in_transit!

          sender_bank_account_id = ColumnService::Accounts.id_of payout_holding.book_transfer_originating_account
          receiver_bank_account_id = ColumnService::Accounts.id_of payout_holding.book_transfer_receiving_account

          ColumnService.post "/transfers/book",
                             idempotency_key: payout_holding.id.to_s,
                             amount: amount_cents.abs,
                             currency_code: "USD",
                             sender_bank_account_id:,
                             receiver_bank_account_id:,
                             description: memo
        end

        true
      end

      private

      def amount_cents
        payout_holding.amount_cents
      end

      def memo
        "HCB-#{local_hcb_code.short_code}"
      end

      def local_hcb_code
        @local_hcb_code ||= payout_holding.local_hcb_code
      end

      def payout_holding
        @payout_holding ||= Reimbursement::PayoutHolding.pending.find(@payout_holding_id)
      end

    end
  end
end
