# frozen_string_literal: true

class Ledger
  class AssertCemsMatchLedgerMappingJob < ApplicationJob
    queue_as :low
    include AssertsRequirements

    def run
      @cts = CanonicalTransaction.all.includes(:ledger_item, :canonical_event_mapping)

      @cts.find_each do |ct|
        safely do
          if (cpem = ct.canonical_event_mapping) && (cpem.subledger&.card_grant || cpem.event)&.ledger != ct.ledger_item&.primary_ledger
            report_anomaly "CanonicalTransaction #{ct.id} canonical_event_mapping does not match Ledger::Item"
          end
        end
      end
    end

  end

end
