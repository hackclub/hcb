# frozen_string_literal: true

class Ledger
  # A Ledger::Item and its HcbCode must hold the same canonical transactions.
  #
  # Comparing the two collections item by item is the same as checking, for
  # every canonical transaction, that it hangs off the same Ledger::Item as the
  # HcbCode sharing its HCB code — a transaction in one collection but not the
  # other is exactly a transaction those two disagree about. Phrased that way
  # the whole assertion is one join instead of a query per ledger item.
  class AssertCtsSyncedWithHcbCodeJob < AssertRequirementJob
    def perform
      @cts = CanonicalTransaction
             .joins("LEFT JOIN hcb_codes ON hcb_codes.hcb_code = canonical_transactions.hcb_code")
             .where("canonical_transactions.ledger_item_id IS DISTINCT FROM hcb_codes.ledger_item_id")
             .select("canonical_transactions.*, hcb_codes.ledger_item_id AS hcb_code_ledger_item_id")

      @cts.find_each do |ct|
        report_anomaly "CanonicalTransaction #{ct.id} is on Ledger::Item #{ct.ledger_item_id || "none"} but HcbCode #{ct.hcb_code} is on Ledger::Item #{ct.hcb_code_ledger_item_id || "none"}"
      end
    end

  end

end
