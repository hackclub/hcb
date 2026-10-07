# frozen_string_literal: true

module Maintenance
  # Backfills the eagerly-created ledger item for invoices that predate
  # Invoice's after_create_commit ledger item callback. An invoice creates no
  # canonical (pending) transaction until it's paid, so nothing else would have
  # created a ledger item for an unpaid invoice. Only invoices still missing a
  # ledger item are processed; the resulting item is "intended" (it has a linked
  # object but no CTs or CPTs).
  class BackfillInvoiceLedgerItemsTask < MaintenanceTasks::Task
    def collection
      Invoice.where.missing(:ledger_item)
    end

    def process(invoice)
      # Mirrors Invoice's after_create_commit callback. It's a no-op if the
      # invoice somehow already has a ledger item.
      return if invoice.ledger_item.present?

      safely do
        invoice.create_ledger_item!(amount_cents: 0, datetime: invoice.created_at, intended_at: invoice.created_at, memo: invoice.smart_memo, short_code: invoice.local_hcb_code.short_code, hcb_code: invoice.local_hcb_code)
      end
    end

  end
end
