# frozen_string_literal: true

module Admin
  class DetectLogicalTransactionAnomaliesJob < ApplicationJob
    queue_as :low

    def perform
      hcb_codes = []
      HcbCode.where(event_id: 183).find_each do |hcb_code|
        hcb_codes << hcb_code.id if hcb_code.ledger_item.nil? || hcb_code.smart_amount_cents != hcb_code.ledger_item.amount_cents
      end

      AdminMailer.logical_transaction_anomalies(hcb_codes: HcbCode.where(id: hcb_codes)).deliver_now
    end

  end
end
