# frozen_string_literal: true

class Ledger
  class AssertCpemsMatchLedgerMappingJob < AssertRequirementJob
    def perform
      @cpts = CanonicalPendingTransaction.where(id: CanonicalPendingEventMapping
                                                    .left_joins(:event, subledger: :card_grant, canonical_pending_transaction: :ledger_item)
                                                    .joins("LEFT JOIN ledger_mappings primary_mappings ON primary_mappings.ledger_item_id = ledger_items.id AND primary_mappings.on_primary_ledger = true")
                                                    .joins("LEFT JOIN ledgers primary_ledgers ON primary_ledgers.id = primary_mappings.ledger_id")
                                                    .joins("LEFT JOIN ledgers cpem_ledgers ON cpem_ledgers.card_grant_id = card_grants.id OR (cpem_ledgers.event_id = events.id AND card_grants.id IS NULL)")
                                                    .where("primary_ledgers.id != cpem_ledgers.id")
                                                    .select("canonical_pending_event_mappings.canonical_pending_transaction_id as canonical_pending_transaction_id"))

      @cpts.find_each do |cpt|
        safely do
          report_anomaly "CanonicalPendingTransaction #{cpt.id} canonical_pending_event_mapping does not match Ledger::Item"
        end
      end
    end

  end

end
