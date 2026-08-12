# frozen_string_literal: true

module Maintenance
  class BackfillLedgerItemSpecialAppearancesTask < MaintenanceTasks::Task
    DISBURSEMENT_TYPES = ["Disbursement::Incoming"].freeze
    EVENT_IDS = [EventMappingEngine::EventIds::HACKATHON_GRANT_FUND, EventMappingEngine::EventIds::WINTER_HARDWARE_WONDERLAND_GRANT_FUND, EventMappingEngine::EventIds::ARGOSY_GRANT_FUND, EventMappingEngine::EventIds::ARGOSY_GRANT_FUND_2025, EventMappingEngine::EventIds::FIRST_TRANSPARENCY_GRANT_FUND, EventMappingEngine::EventIds::GENE_HAAS_GRANT_FUND].freeze

    def collection
      candidates = Disbursement.where(source_event_id: EVENT_IDS)
                               .or(Disbursement.where(id: CardGrant.where.not(disbursement_id: nil).select(:disbursement_id)))

      Ledger::Item.where(
        special_appearance: nil,
        linked_object_type: DISBURSEMENT_TYPES,
        linked_object_id: candidates.select(:id)
      )
    end

    def process(item)
      return unless Ledger::Item::SpecialAppearance.find_by_linked_object(item.linked_object)

      item.refresh!
    end

  end
end
