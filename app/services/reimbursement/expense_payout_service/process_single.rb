# frozen_string_literal: true

module Reimbursement
  module ExpensePayoutService
    class ProcessSingle < Reimbursement::ProcessSingleBase
      def initialize(expense_payout_id:)
        super(record_id: expense_payout_id)
      end

      private

      def record
        @record ||= Reimbursement::ExpensePayout.pending.find(@record_id)
      end
    end
  end
end
