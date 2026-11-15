# frozen_string_literal: true

module Maintenance
  # Recomputes the ledger items of voided invoices, whose cached status and
  # ledger mapping can predate the void. Without transactions, an item reads
  # "canceled", or "intended" if the invoice was manually marked as paid (which
  # voids it). map! rather than refresh! so an item that was never placed on
  # its event's ledger gets placed too.
  class RefreshVoidedInvoiceLedgerItemsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.where(linked_object_type: "Invoice", linked_object_id: Invoice.void_v2.select(:id))
    end

    def process(ledger_item)
      ledger_item.map!
    end

  end
end
