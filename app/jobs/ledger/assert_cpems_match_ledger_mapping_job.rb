# frozen_string_literal: true

class Ledger
  class AssertCpemsMatchLedgerMappingJob < AssertRequirementJob
    def perform
      @cpts = CanonicalPendingTransaction.all.includes(:ledger_item, :canonical_pending_event_mapping)

      @cpts.find_each do |cpt|
        safely do
          if (cpem = cpt.canonical_pending_event_mapping) && (cpem.subledger&.card_grant || cpem.event)&.ledger != cpt.ledger_item&.primary_ledger
            report_anomaly "CanonicalPendingTransaction #{cpt.id} canonical_pending_event_mapping does not match Ledger::Item"
          end
        end
      end
    end

  end

end
