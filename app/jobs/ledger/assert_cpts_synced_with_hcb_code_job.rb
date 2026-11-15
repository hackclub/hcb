# frozen_string_literal: true

class Ledger
  # A Ledger::Item and its HcbCode must hold the same canonical pending
  # transactions. See AssertCtsSyncedWithHcbCodeJob for why checking each
  # transaction is equivalent to comparing the two collections.
  class AssertCptsSyncedWithHcbCodeJob < AssertRequirementJob
    def perform
      @cpts = CanonicalPendingTransaction
              .joins("LEFT JOIN hcb_codes ON hcb_codes.hcb_code = canonical_pending_transactions.hcb_code")
              .where("canonical_pending_transactions.ledger_item_id IS DISTINCT FROM hcb_codes.ledger_item_id")
              .select("canonical_pending_transactions.*, hcb_codes.ledger_item_id AS hcb_code_ledger_item_id")

      @cpts.find_each do |cpt|
        report_anomaly "CanonicalPendingTransaction #{cpt.id} is on Ledger::Item #{cpt.ledger_item_id || "none"} but HcbCode #{cpt.hcb_code} is on Ledger::Item #{cpt.hcb_code_ledger_item_id || "none"}"
      end
    end

  end

end
