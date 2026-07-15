# frozen_string_literal: true

module PendingTransactionEngine
  module RawPendingFeeRevenueTransactionService
    module FeeRevenue
      class Import
        def run
          pending_fee_revenues.find_each(batch_size: 100) do |fee_revenue|
            ::RawPendingFeeRevenueTransaction.find_or_initialize_by(fee_revenue_transaction_id: fee_revenue.id.to_s).tap do |t|
              t.amount_cents = fee_revenue.amount_cents
              t.date_posted = fee_revenue.created_at
            end.save!
          end

          nil
        end

        private

        def pending_fee_revenues
          @pending_fee_revenues ||= ::FeeRevenue.in_transit_or_pending
        end

      end
    end
  end
end
