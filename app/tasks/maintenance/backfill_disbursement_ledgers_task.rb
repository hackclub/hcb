# frozen_string_literal: true

module Maintenance
  # Fills source_ledger_id and destination_ledger_id on disbursements made
  # before Disbursement started writing them
  # (https://github.com/hackclub/hcb/issues/14163). A side with a subledger
  # points at its card grant's ledger and the rest at the event's, the same
  # rule Disbursement#ledger_for follows. A subledger without a card grant
  # leaves its side nil.
  #
  # Only empty sides are written, so it's safe to re-run.
  class BackfillDisbursementLedgersTask < MaintenanceTasks::Task
    def collection
      Disbursement.where(source_ledger_id: nil).or(Disbursement.where(destination_ledger_id: nil))
    end

    def process(disbursement)
      disbursement.update_columns(
        source_ledger_id: ledger_for(disbursement.source_event, disbursement.source_subledger)&.id,
        destination_ledger_id: ledger_for(disbursement.destination_event, disbursement.destination_subledger)&.id
      )
    end

    private

    def ledger_for(event, subledger)
      return subledger.card_grant&.ledger if subledger.present?

      event&.ledger
    end

  end
end
