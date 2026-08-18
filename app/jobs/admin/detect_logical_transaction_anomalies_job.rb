# frozen_string_literal: true

module Admin
  class DetectLogicalTransactionAnomaliesJob < ApplicationJob
    queue_as :low

    def perform(event_id: 183)
      event = Event.find(event_id)

      hcb_codes = []
      HcbCode.where(event_id:).on_main_ledger.find_each do |hcb_code|
        if !(hcb_code.ledger_item.nil? && hcb_code.no_transactions?) && (hcb_code.ledger_item.nil? || hcb_code.smart_amount_cents != hcb_code.ledger_item.amount_cents)
          hcb_codes << hcb_code.id
        end
      end

      ledger_items = orphaned_ledger_item_ids(event)

      if hcb_codes.any? || ledger_items.any?
        AdminMailer.logical_transaction_anomalies(event:, hcb_codes: HcbCode.where(id: hcb_codes), ledger_items: Ledger::Item.where(id: ledger_items)).deliver_now
      end
    end

    private

    # Items on the event's ledger that no HCB code of that event points at.
    #
    # Expressed as a LEFT JOIN anti-join rather than `where.not(id: <subquery>)`:
    # that form compiles to `NOT IN`, and because `hcb_codes.ledger_item_id` is
    # nullable, a single NULL anywhere in the subquery makes the whole predicate
    # UNKNOWN and the query returns nothing at all. `IS DISTINCT FROM` also keeps
    # a NULL `event_id` on the joined row counting as a mismatch rather than
    # dropping it.
    #
    # The join is also scoped to the event's own ledger. Comparing every item in
    # the table against one event's HCB codes would report every other event's
    # items as anomalies.
    def orphaned_ledger_item_ids(event)
      ledger = event.ledger
      return [] if ledger.nil?

      ledger.items
            .left_joins(:hcb_code)
            .where("hcb_codes.id IS NULL OR hcb_codes.event_id IS DISTINCT FROM ?", event.id)
            .pluck(Ledger::Item.arel_table[:id])
    end

  end
end
