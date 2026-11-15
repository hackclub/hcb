# frozen_string_literal: true

class Ledger
  # A Ledger::Item's amount is the sum of its canonical transactions and its
  # unsettled outgoing pending transactions, so an item holding neither can only
  # be worth nothing. A non-zero amount there means either the amount or the
  # counter caches are stale, and the item is contributing a balance no
  # transaction backs.
  class AssertEmptyItemsHaveZeroAmountJob < AssertRequirementJob
    def perform
      @ledger_items = Ledger::Item.where(ct_count: 0, cpt_count: 0).where.not(amount_cents: 0)

      @ledger_items.find_each do |item|
        report_anomaly "Ledger::Item #{item.hashid} has no transactions but an amount_cents of #{item.amount_cents}"
      end
    end

  end

end
