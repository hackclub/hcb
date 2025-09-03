# frozen_string_literal: true

module BankFeeService
  class Nightly
    def run
      if BankFee.pending.present? || FeeRevenue.pending.present?

        # all transfers to operating must happen before
        # transfers to main. this is because operating sits at $0.
        # - @sampoder

        bank_fees_to_main = []
        fee_revenues_to_main = []

        BankFee.pending.find_each(batch_size: 100) do |bank_fee|
          if bank_fee.book_transfer_to?(:fs_operating)
            ::BankFeeService::ProcessSingle.new(bank_fee_id: bank_fee.id).run
          else
            bank_fees_to_main << bank_fee
          end
        end

        FeeRevenue.pending.find_each(batch_size: 100) do |fee_revenue|
          if fee_revenue.book_transfer_to?(:fs_operating)
            ::FeeRevenueService::ProcessSingle.new(fee_revenue_id: fee_revenue.id).run
          else
            fee_revenues_to_main << fee_revenue
          end
        end

        bank_fees_to_main.each do |bank_fee|
          ::BankFeeService::ProcessSingle.new(bank_fee_id: bank_fee.id).run
        end

        fee_revenues_to_main.each do |fee_revenue|
          ::FeeRevenueService::ProcessSingle.new(fee_revenue_id: fee_revenue.id).run
        end
      end

      BankFee.in_transit.find_each(batch_size: 100) do |bank_fee|
        cpt = bank_fee.canonical_pending_transaction

        next unless cpt
        next unless cpt.settled?

        raise ArgumentError, "anomaly detected when attempting to mark settled bank fee #{bank_fee.id}" if anomaly_detected?(bank_fee:)

        begin
          bank_fee.mark_settled!
        rescue => e
          Rails.error.report(e)
        end
      end

      FeeRevenue.in_transit.find_each(batch_size: 100) do |fee_revenue|
        if fee_revenue.canonical_transaction
          fee_revenue.mark_settled!
        end
      end
    end

    private

    def anomaly_detected?(bank_fee:)
      ::PendingEventMappingEngine::AnomalyDetection::BadSettledMapping.new(canonical_pending_transaction: bank_fee.canonical_pending_transaction).run
    end

  end
end
