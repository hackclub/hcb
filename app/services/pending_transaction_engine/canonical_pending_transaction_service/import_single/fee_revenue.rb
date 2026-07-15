# frozen_string_literal: true

module PendingTransactionEngine
  module CanonicalPendingTransactionService
    module ImportSingle
      class FeeRevenue
        def initialize(raw_pending_fee_revenue_transaction:)
          @raw_pending_fee_revenue_transaction = raw_pending_fee_revenue_transaction
        end

        def run
          return existing_canonical_pending_transaction if existing_canonical_pending_transaction

          attrs = {
            date: @raw_pending_fee_revenue_transaction.date,
            memo: @raw_pending_fee_revenue_transaction.memo,
            amount_cents: @raw_pending_fee_revenue_transaction.amount_cents,
            raw_pending_fee_revenue_transaction_id: @raw_pending_fee_revenue_transaction.id,
            fronted: @raw_pending_fee_revenue_transaction.amount_cents.positive?,
            fee_waived: true
          }
          cpt = nil
          ActiveRecord::Base.transaction do
            cpt = ::CanonicalPendingTransaction.create!(attrs)

            TransactionCategoryService.new(model: cpt).set!(slug: "hcb-revenue", assignment_strategy: "automatic")
          end

          cpt
        end

        private

        def existing_canonical_pending_transaction
          @existing_canonical_pending_transaction ||= ::CanonicalPendingTransaction.where(raw_pending_fee_revenue_transaction_id: @raw_pending_fee_revenue_transaction.id).first
        end

      end
    end
  end
end
