# frozen_string_literal: true

module Maintenance
  # Backfills the eagerly-created ledger item for invoices that predate
  # Invoice#ensure_ledger_item. An invoice creates no canonical (pending)
  # transaction until it's paid, so nothing else would have created a ledger
  # item for an unpaid invoice. Only invoices still missing a ledger item are
  # processed; the resulting item is "empty" (it has a linked object but no CTs
  # or CPTs).
  class BackfillInvoiceLedgerItemsTask < MaintenanceTasks::Task
    def collection
      Invoice.where.missing(:ledger_item)
    end

    def process(invoice)
      # Reuse the same creation path as the after_create_commit callback so the
      # eager item stays defined in one place. It's a no-op if the invoice
      # somehow already has a ledger item.
      invoice.send(:ensure_ledger_item)
    end

  end
end
