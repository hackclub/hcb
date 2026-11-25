# frozen_string_literal: true

module Maintenance
  # Invoices voided before they were paid left their ledger item "intended":
  # the item has no transactions to refresh it, and voiding didn't refresh it
  # until Invoice#refresh_ledger_item. Refreshing recomputes the status as
  # "canceled".
  class RefreshVoidedInvoiceLedgerItemsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.intended.where(linked_object_type: "Invoice", linked_object_id: Invoice.void_v2.select(:id))
    end

    def process(ledger_item)
      ledger_item.refresh!
    end

  end
end
