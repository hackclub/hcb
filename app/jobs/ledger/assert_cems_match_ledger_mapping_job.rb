# frozen_string_literal: true

class Ledger
  class AssertCemsMatchLedgerMappingJob < AssertRequirementJob
    def perform
      @cts = CanonicalTransaction.where(id: CanonicalEventMapping
                                            .left_joins(:event, subledger: :card_grant, canonical_transaction: :ledger_item)
                                            .joins("LEFT JOIN ledger_mappings primary_mappings ON primary_mappings.ledger_item_id = ledger_items.id AND primary_mappings.on_primary_ledger = true")
                                            .joins("LEFT JOIN ledgers primary_ledgers ON primary_ledgers.id = primary_mappings.ledger_id")
                                            .joins("LEFT JOIN ledgers cem_ledgers ON cem_ledgers.card_grant_id = card_grants.id OR (cem_ledgers.event_id = events.id AND card_grants.id IS NULL)")
                                            .where("primary_ledgers.id != cem_ledgers.id")
                                            .select("canonical_event_mappings.canonical_transaction_id as canonical_transaction_id"))

      @cts.find_each do |ct|
        safely do
          report_anomaly "CanonicalTransaction #{ct.id} canonical_event_mapping does not match Ledger::Item"
        end
      end
    end

  end

end
