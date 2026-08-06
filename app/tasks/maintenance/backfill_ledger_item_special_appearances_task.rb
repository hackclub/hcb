# frozen_string_literal: true

module Maintenance
  # Backfills `ledger_items.special_appearance` for items that predate the column.
  #
  # There's nothing on the item itself to read an appearance off of: the memo isn't
  # a record of one, because `Ledger::Item#refresh!` regenerates the memo from
  # `calculate_system_memo` every time — so a fund transfer's memo says "Transfer
  # from Hackathon Grant Fund" until the column is set, at which point it becomes
  # the appearance's memo. The appearance has to come back from the same place a
  # new item's does: the linked object.
  #
  # This is a one-time bridge; new items get the column on their first refresh.
  class BackfillLedgerItemSpecialAppearancesTask < MaintenanceTasks::Task
    DISBURSEMENT_TYPES = ["Disbursement::Incoming", "Disbursement::Outgoing"].freeze

    def collection
      # Narrow to the transfers that could earn an appearance — out of a fund, or
      # carrying a card grant. `process` is the authority on which one applies (an
      # Argosy transfer from before the 2024 cutoff, say, earns none).
      candidates = Disbursement.where(source_event_id: Ledger::Item::SpecialAppearance.fund_event_ids)
                               .or(Disbursement.where(id: CardGrant.where.not(disbursement_id: nil).select(:disbursement_id)))

      Ledger::Item.where(
        special_appearance: nil,
        linked_object_type: DISBURSEMENT_TYPES,
        linked_object_id: candidates.select(:id)
      )
    end

    def process(item)
      return unless Ledger::Item::SpecialAppearance.for(item.linked_object)

      item.refresh!
    end

  end
end
