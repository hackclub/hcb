# frozen_string_literal: true

module Reimbursement
  module PayoutHoldingService
    class ProcessSingle < Reimbursement::ProcessSingleBase
      def initialize(payout_holding_id:)
        super(record_id: payout_holding_id)
      end

      private

      def record
        @record ||= Reimbursement::PayoutHolding.find(@record_id)
      end
    end
  end
end
