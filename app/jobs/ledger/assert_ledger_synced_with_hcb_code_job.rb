# frozen_string_literal: true

class Ledger
  class AssertLedgerSyncedWithHcbCodeJob < AssertRequirementJob
    def perform
      @ledger_items = Ledger::Item.where(id: Ledger::Mapping
                                             .left_joins(ledger: [:event, { card_grant: :subledger }], ledger_item: :hcb_code)
                                             .joins("LEFT JOIN events hcb_events ON hcb_events.id = hcb_codes.event_id")
                                             .joins("LEFT JOIN card_grants hcb_subledgers ON hcb_subledgers.id = hcb_codes.subledger_id")
                                             .where("events.id != hcb_events.id OR subledgers.id != hcb_subledgers.id")
                                             .select("ledger_mappings.ledger_item_id as ledger_item_id"))

      @ledger_items.find_each do |item|
        safely do
          hcb_code = item.hcb_code
          report_anomaly "Ledger::Item #{item.hashid} ledger does not match HcbCode #{hcb_code.hashid} ledger"
        end
      end

    end

  end

end
