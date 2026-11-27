# frozen_string_literal: true

module Maintenance
  # Fills source_ledger_id and destination_ledger_id on disbursements made
  # before Disbursement started writing them
  # (https://github.com/hackclub/hcb/issues/14163). A side with a subledger
  # points at its card grant's ledger and the rest at the event's, the same
  # rule Disbursement#ledger_for follows. A subledger without a card grant
  # leaves its side nil.
  #
  # Processed in batches so each iteration is two UPDATEs rather than a query
  # per row. Only empty sides are written, so it's safe to re-run.
  class BackfillDisbursementLedgersTask < MaintenanceTasks::Task
    def collection
      Disbursement
        .where(source_ledger_id: nil)
        .or(Disbursement.where(destination_ledger_id: nil))
        .in_batches(of: 10_000)
    end

    def process(batch)
      batch.where(source_ledger_id: nil).update_all("source_ledger_id = #{ledger_sql(subledger: "source_subledger_id", event: "source_event_id")}")
      batch.where(destination_ledger_id: nil).update_all("destination_ledger_id = #{ledger_sql(subledger: "destination_subledger_id", event: "event_id")}")
    end

    private

    def ledger_sql(subledger:, event:)
      <<~SQL.squish
        CASE WHEN disbursements.#{subledger} IS NOT NULL THEN
          (SELECT ledgers.id FROM ledgers
           INNER JOIN card_grants ON card_grants.id = ledgers.card_grant_id
           WHERE card_grants.subledger_id = disbursements.#{subledger} AND ledgers."primary")
        ELSE
          (SELECT ledgers.id FROM ledgers
           WHERE ledgers.event_id = disbursements.#{event} AND ledgers."primary")
        END
      SQL
    end

  end
end
