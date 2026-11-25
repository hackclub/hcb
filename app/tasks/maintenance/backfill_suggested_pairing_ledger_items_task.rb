# frozen_string_literal: true

module Maintenance
  # Points every existing suggested pairing at its HCB code's ledger item
  # (https://github.com/hackclub/hcb/issues/15698). New pairings have carried
  # both since #15779, so this only fills the rows from before that, plus any
  # written by the old code while that deploy rolled out. Pairings whose HCB
  # code has no ledger item are left alone; they're deleted when the column
  # becomes required.
  #
  # Processed in batches so each iteration is a single UPDATE rather than a
  # query per row. Safe to re-run: filled rows drop out of the collection.
  class BackfillSuggestedPairingLedgerItemsTask < MaintenanceTasks::Task
    def collection
      SuggestedPairing
        .where(ledger_item_id: nil)
        .where(hcb_code_id: HcbCode.where.not(ledger_item_id: nil).select(:id))
        .in_batches(of: 10_000)
    end

    def process(batch)
      batch.update_all(<<~SQL.squish)
        ledger_item_id = (SELECT hcb_codes.ledger_item_id FROM hcb_codes WHERE hcb_codes.id = suggested_pairings.hcb_code_id)
      SQL
    end

  end
end
