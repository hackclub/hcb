# frozen_string_literal: true

class Ledger
  class AssertNoOrphanedCtsJob < AssertRequirementJob
    def perform
      @cts = CanonicalTransaction.where(ledger_item_id: nil)

      @cts.find_each do |ct|
        report_anomaly "CanonicalTransaction #{ct.id} is orphaned (no Ledger::Item)"
      end
    end

  end

end
