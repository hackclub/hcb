# frozen_string_literal: true

module Maintenance
  # Backfills the eagerly-created ledger item for scheduled ACH transfers that
  # predate AchTransfer's after_create_commit ledger item callback. A scheduled
  # transfer creates no pending transaction until it's sent, so nothing else
  # would have created a ledger item for one still waiting to go out. Only
  # transfers that are still pending or scheduled and missing a ledger item are
  # processed; the resulting item is "intended" (it has a linked object but no
  # CTs or CPTs). Transfers that were rejected before this callback existed are
  # left alone: they never had a ledger item and nothing needs one now.
  class BackfillScheduledAchTransferLedgerItemsTask < MaintenanceTasks::Task
    def collection
      AchTransfer.where(aasm_state: [:pending, :scheduled]).where.not(scheduled_on: nil).where.missing(:ledger_item)
    end

    def process(ach_transfer)
      # Mirrors AchTransfer's after_create_commit callback. It's a no-op if the
      # transfer somehow already has a ledger item.
      return if ach_transfer.ledger_item.present?

      safely do
        ach_transfer.create_ledger_item!(amount_cents: 0, datetime: ach_transfer.created_at, intended_at: ach_transfer.created_at, memo: "ACH to #{ach_transfer.smart_memo}", short_code: ach_transfer.local_hcb_code.short_code, hcb_code: ach_transfer.local_hcb_code)
      end
    end

  end
end
