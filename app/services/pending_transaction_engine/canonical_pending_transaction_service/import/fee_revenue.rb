# frozen_string_literal: true

module PendingTransactionEngine
  module CanonicalPendingTransactionService
    module Import
      class FeeRevenue
        def run
          raw_pending_fee_revenue_transactions.find_each(batch_size: 100) do |rpfrt|
            ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::FeeRevenue.new(raw_pending_fee_revenue_transaction: rpfrt).run
          end
        end

        private

        def raw_pending_fee_revenue_transactions
          RawPendingFeeRevenueTransaction.where.missing :canonical_pending_transaction
        end

      end
    end
  end
end
