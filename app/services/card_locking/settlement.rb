# frozen_string_literal: true

module CardLocking
  # Enqueues receipt-timing materialization when a Stripe card charge settles.
  # Both transaction engines run in parallel and call in here, so the coupling to
  # each engine's models lives in one place.
  module Settlement
    module_function

    # Old engine: a canonical transaction was mapped to an event.
    #
    # Checks the in-memory amount before the stripe_card lookup so non-card and
    # positive mappings (fees, donations, incoming) skip the extra DB reads.
    def on_canonical_transaction(canonical_transaction)
      ct = canonical_transaction
      return unless ct&.amount_cents&.negative? && ct.stripe_card.present?

      hcb_code = ct.local_hcb_code
      MaterializeChargeJob.perform_later(hcb_code_id: hcb_code.id) if hcb_code
    end

    # New engine: a ledger item was mapped. Fires on create/update/destroy (the
    # job is idempotent, so the extra fires are harmless); only primary-ledger,
    # negative card charges do any work.
    #
    # A ledger item groups the canonical transactions that share an HcbCode. Find
    # the charge's Stripe-card canonical transaction and materialize its HcbCode
    # (parity with the old-engine hook). This does not rely on the item -> hcb_code
    # has_one, which depends on the ledger_item_id backfill.
    def on_ledger_item(ledger_item, on_primary:)
      item = ledger_item
      return unless on_primary && item&.amount_cents&.negative?

      ct = item.canonical_transactions.detect { |t| t.stripe_card.present? }
      hcb_code = ct&.local_hcb_code
      MaterializeChargeJob.perform_later(hcb_code_id: hcb_code.id) if hcb_code
    end
  end
end
