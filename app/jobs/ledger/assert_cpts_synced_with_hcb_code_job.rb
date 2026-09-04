# frozen_string_literal: true

class Ledger
  class AssertCptsSyncedWithHcbCodeJob < ApplicationJob
    queue_as :low
    include AssertsRequirements

    def run
      @ledger_items = Ledger::Item.all.includes(:canonical_pending_transactions, hcb_code: [:canonical_pending_transactions])

      @ledger_items.find_each do |item|
        safely do
          hcb_code = item.hcb_code
          if hcb_code.canonical_pending_transactions.reorder(id: :asc) != item.canonical_pending_transactions.reorder(id: :asc)
            report_anomaly "Ledger::Item #{item.hashid} canonical_pending_transactions do not match HcbCode #{hcb_code.hashid} canonical_pending_transactions"
          end
        end
      end
    end

  end

end
