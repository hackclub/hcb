# frozen_string_literal: true

module Reimbursement
  module ExpensePayoutService
    class Nightly
      def run
        Reimbursement::ExpensePayout.pending.find_each(batch_size: 100) do |expense_payout|
          next if payout_holding.report.user.payout_method_type == User::PayoutMethod::WiseTransfer.name

          Reimbursement::ExpensePayoutService::ProcessSingle.new(expense_payout_id: expense_payout.id).run
        end

        Reimbursement::PayoutHolding.pending.find_each(batch_size: 100) do |payout_holding|
          next if payout_holding.report.user.payout_method_type == User::PayoutMethod::WiseTransfer.name

          Reimbursement::PayoutHoldingService::ProcessSingle.new(payout_holding_id: payout_holding.id).run
        end

        Reimbursement::ExpensePayout.in_transit.find_each(batch_size: 100) do |expense_payout|
          if expense_payout.canonical_transactions.any?
            expense_payout.mark_settled!
          end
        end

        Reimbursement::PayoutHolding.in_transit.find_each(batch_size: 100) do |payout_holding|
          next if payout_holding.report.user.payout_method_type == User::PayoutMethod::WiseTransfer.name

          if payout_holding.canonical_transactions.any? || payout_holding.canonical_pending_transaction.present?
            payout_holding.mark_settled!
          end
        end
      end

    end
  end
end
