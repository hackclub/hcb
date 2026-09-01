# frozen_string_literal: true

class Ledger
  class AssertLedgerSyncedWithHcbCodeJob < ApplicationJob
    queue_as :low
    include AssertsRequirements

    def run
      @ledger_items = Ledger::Item.all.includes(hcb_code: [:event, { subledger: [:card_grant] }])

      @ledger_items.find_each do |item|
        safely do
          hcb_code = item.hcb_code
          if (hcb_code.subledger&.card_grant || hcb_code.event)&.ledger != item.primary_ledger
            report_anomaly "Ledger::Item #{item.hashid} ledger does not match HcbCode #{hcb_code.hashid} ledger"
          end

          if hcb_code.custom_memo.presence != item.custom_memo.presence
            report_anomaly "Ledger::Item #{item.hashid} custom_memo does not match HcbCode #{hcb_code.hashid} custom_memo"
          end
        end
      end
    end

  end
end
