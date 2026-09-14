# frozen_string_literal: true

class Ledger
  class AssertLedgerItemMemoMatchesHcbCodeJob < AssertRequirementJob
    def perform
      @ledger_items = Ledger::Item.where.associated(:hcb_code).includes(:hcb_code, hcb_code: [:canonical_transactions, :canonical_pending_transactions])

      @ledger_items.find_each do |item|
        safely do
          if item.hcb_code.custom_memo.presence != item.custom_memo.presence
            report_anomaly "Ledger::Item #{item.hashid} custom_memo does not match HcbCode #{item.hcb_code.hashid} custom_memo"
          end
        end
      end
    end

  end

end
