# frozen_string_literal: true

class Ledger
  class AssertNoOrphanedCtsJob < ApplicationJob
    queue_as :low
    include AssertsRequirements

    def run
      @cts = CanonicalTransaction.all.includes(:ledger_item)

      @cts.find_each do |ct|
        safely do
          if ct.ledger_item.nil?
            report_anomaly "CanonicalTransaction #{ct.id} is orphaned (no Ledger::Item)"
          end
        end
      end
    end

  end
end
