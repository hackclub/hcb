# frozen_string_literal: true

class Ledger
  class AssertNoOrphanedCptsJob < ApplicationJob
    queue_as :low
    include AssertsRequirements

    def run
      @cpts = CanonicalPendingTransaction.all.includes(:ledger_item)

      @cpts.find_each do |cpt|
        safely do
          if cpt.ledger_item.nil?
            report_anomaly "CanonicalPendingTransaction #{cpt.id} is orphaned (no Ledger::Item)"
          end
        end
      end
    end

  end
end
