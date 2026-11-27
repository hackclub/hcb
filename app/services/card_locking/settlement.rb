# frozen_string_literal: true

module CardLocking
  # Enqueues receipt-timing materialization when a Stripe card charge settles.
  # Both transaction engines run in parallel and call in here, so the coupling to
  # each engine's models lives in one place.
  module Settlement
    module_function

    # Old engine: a canonical transaction was mapped to an event. Materializes
    # the transaction's ledger item; one that has no item yet is picked up by
    # the new-engine hook once it is mapped.
    #
    # Checks the in-memory amount before the stripe_card lookup so non-card and
    # positive mappings (fees, donations, incoming) skip the extra DB reads.
    def on_canonical_transaction(canonical_transaction)
      ct = canonical_transaction
      return unless ct&.amount_cents&.negative? && ct.stripe_card.present?

      MaterializeChargeJob.perform_later(ledger_item_id: ct.ledger_item_id) if ct.ledger_item_id
    end

    # New engine: a ledger item was mapped. Fires on create/update/destroy (the
    # job is idempotent, so the extra fires are harmless); only primary-ledger,
    # negative card charges do any work.
    def on_ledger_item(ledger_item, on_primary:)
      item = ledger_item
      return unless on_primary && item&.amount_cents&.negative? && item.linked_object_type == "CardCharge"

      MaterializeChargeJob.perform_later(ledger_item_id: item.id)
    end
  end
end
