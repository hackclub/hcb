# frozen_string_literal: true

# Test-only helper that mirrors what Ledger::Mapper does in production.
#
# In production, Ledger::Mapper figures out which ledger a Ledger::Item belongs
# to by inspecting its canonical (pending) transaction's raw source — a Column
# account number, a Stripe card, a linked object, etc. Factory-built canonical
# transactions carry none of that; specs instead say "this transaction belongs
# to this event" by creating a CanonicalEventMapping (or assigning `event:`).
# The ledger never reads those mappings, so the item stays unmapped and
# Event#balance — which now sums the ledger — reports $0.
#
# This bridges that gap for the test suite: once a factory has associated a
# transaction with an event (and no subledger), place the transaction's ledger
# item on that event's primary ledger so ledger balances match the canonical
# transaction totals the specs were written against.
module FactoryLedgerMapping
  module_function

  def map_to_primary_ledger(transaction)
    return if transaction.nil?

    # Work on a freshly-loaded copy: the object we were handed is the one the
    # spec holds (via `let`/local), and reloading it or reading its associations
    # would pollute its association cache — e.g. caching `event` as nil before a
    # spec's own `before` block creates the mapping.
    transaction = transaction.class.find_by(id: transaction.id)
    return if transaction.nil?

    event = transaction.event
    return if event.nil?

    # Subledger (e.g. card grant) transactions belong on a different ledger;
    # leave those to the production flows that create them.
    return if transaction.subledger.present?

    ledger_item = transaction.ledger_item
    return if ledger_item.nil?

    ledger = event.ledger
    return if ledger.nil?

    Ledger::Mapping.map_primary!(ledger:, ledger_item:, mapped_by: Ledger::Mapper::SYSTEM)

    # Recompute cached columns (amount_cents, ct_count/cpt_count, status, …) now
    # that the item knows its primary ledger — the fronted-balance portion of
    # calculate_amount_cents depends on `primary_ledger.can_front_balance?`.
    ledger_item.refresh!
  end
end
