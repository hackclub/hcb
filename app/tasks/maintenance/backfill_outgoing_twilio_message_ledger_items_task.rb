# frozen_string_literal: true

module Maintenance
  # Points every existing outgoing Twilio message at its HCB code's ledger
  # item. New messages have carried both since the column was added, so this
  # only fills the rows from before that, plus any written by the old code
  # while that deploy rolled out. Messages whose HCB code has no ledger item
  # are left alone: nothing reads a message past its ten-minute reply window.
  #
  # Processed in batches so each iteration is a single UPDATE rather than a
  # query per row. Safe to re-run: filled rows drop out of the collection.
  class BackfillOutgoingTwilioMessageLedgerItemsTask < MaintenanceTasks::Task
    def collection
      OutgoingTwilioMessage
        .where(ledger_item_id: nil)
        .where(hcb_code_id: HcbCode.where.not(ledger_item_id: nil).select(:id))
        .in_batches(of: 10_000)
    end

    def process(batch)
      batch.update_all(<<~SQL.squish)
        ledger_item_id = (SELECT hcb_codes.ledger_item_id FROM hcb_codes WHERE hcb_codes.id = outgoing_twilio_messages.hcb_code_id)
      SQL
    end

  end
end
