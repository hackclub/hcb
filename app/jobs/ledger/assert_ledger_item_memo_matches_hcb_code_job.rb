# frozen_string_literal: true

class Ledger
  class AssertLedgerItemMemoMatchesHcbCodeJob < ApplicationJob
    queue_as :low
    include AssertsRequirements

    def run
      @ledger_items = Ledger::Item.where.associated(:hcb_code).includes(:hcb_code)

      @ledger_items.find_each do |item|
        safely do
          if hcb_code.custom_memo.presence != item.custom_memo.presence
            report_anomaly "Ledger::Item #{item.hashid} custom_memo does not match HcbCode #{hcb_code.hashid} custom_memo"
          end
        end
      end
    end

  end

end
