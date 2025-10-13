# frozen_string_literal: true

module Reimbursement
  module ExpensePayoutService
    class ProcessSingle
      def initialize(expense_payout_id:)
        @expense_payout_id = expense_payout_id
      end

      def run
        raise ArgumentError, "must be a pending expense payout only" unless expense_payout.pending?

        ActiveRecord::Base.transaction do
          expense_payout.mark_in_transit!

          sender_bank_account_id = ColumnService::Accounts.id_of expense_payout.book_transfer_originating_account
          receiver_bank_account_id = ColumnService::Accounts.id_of expense_payout.book_transfer_receiving_account

          ColumnService.post "/transfers/book",
                             idempotency_key: expense_payout.public_id,
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
        expense_payout.amount_cents
      end

      def memo
        "HCB-#{local_hcb_code.short_code}"
      end

      def local_hcb_code
        @local_hcb_code ||= expense_payout.local_hcb_code
      end

      def expense_payout
        @expense_payout ||= Reimbursement::ExpensePayout.pending.find(@expense_payout_id)
      end

    end
  end
end
