# frozen_string_literal: true

module Admin
  class DetectLogicalTransactionAnomaliesJob < ApplicationJob
    queue_as :low

    def perform
      hcb_codes = []
      HcbCode.where(event_id:).find_each do |hcb_code|
        hcb_codes << hcb_code.id if hcb_code.smart_amount_cents != hcb_code.ledger_item.amount_cents || (hcb_code.ledger_item.nil? && hcb_code.no_transactions?)
      end

      ledger_items = []
      Ledger::Item.where.not(id: HcbCode.where(event_id:).select(:ledger_item_id)).find_each do |ledger_item|
        ledger_items << ledger_item.id
      end

      AdminMailer.logical_transaction_anomalies(hcb_codes: HcbCode.where(id: hcb_codes), ledger_items: LedgerItem.where(id: ledger_items)).deliver_now
    end

    def event_id
      183
    end

  end
end
