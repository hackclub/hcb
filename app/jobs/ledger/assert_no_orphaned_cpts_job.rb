# frozen_string_literal: true

class Ledger
  class AssertNoOrphanedCptsJob < AssertRequirementJob
    def perform
      @cpts = CanonicalPendingTransaction.where(ledger_item_id: nil)

      @cpts.find_each do |cpt|
        report_anomaly "CanonicalPendingTransaction #{cpt.id} is orphaned (no Ledger::Item)"
      end
    end

  end

end
