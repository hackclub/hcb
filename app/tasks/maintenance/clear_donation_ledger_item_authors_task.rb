# frozen_string_literal: true

module Maintenance
  # One-time cleanup: `ledger_items.author_id` is a cached column, only
  # recomputed when an item is refreshed. In-person donations used to be
  # attributed to the organizer who collected them, which read as if that
  # organizer had made the payment. Donations no longer have an author, so
  # clear the ones already stored instead of waiting for each item to be
  # touched. Run once after deploying.
  class ClearDonationLedgerItemAuthorsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.where(linked_object_type: "Donation").where.not(author_id: nil)
    end

    def process(ledger_item)
      ledger_item.update!(author_id: nil)
    end

  end
end
