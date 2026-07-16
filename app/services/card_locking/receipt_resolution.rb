# frozen_string_literal: true

module CardLocking
  # Keeps a charge's persisted receipt timing in sync when a receipt is attached,
  # removed, or the charge is marked no/lost, then triggers an unlock recompute.
  # Uploading a receipt can only ever unlock, so the recompute is unlock-only.
  module ReceiptResolution
    module_function

    # A receipt was created or updated. Materialize synchronously so the unlock
    # job sees the resolution, then recompute the lock. notify_progress lets a
    # still-locked cardholder hear that this upload landed but more remain.
    def on_receipt_upsert(receipt)
      charge = receipt.receiptable
      charge.materialize_card_locking! if charge.is_a?(HcbCode) && charge.card_locking_chargeable?
      enqueue_unlock(cardholder_for(charge), notify_progress: true)
    end

    # A receipt was destroyed.
    def on_receipt_destroy(receipt)
      charge = receipt.receiptable
      # receipt_resolved_at is only ever cleared here, never revised. Once a charge
      # is resolved the timestamp is frozen, so destroying an earlier receipt while
      # a later one remains (card_locking_resolved? still true) leaves the original
      # resolution timestamp in place. It resets to nil only when the charge becomes
      # genuinely unresolved again (no receipts, not marked no/lost).
      if charge.is_a?(HcbCode) && charge.card_locking_chargeable? && !charge.card_locking_resolved?
        charge.update_columns(receipt_resolved_at: nil)
      end
      enqueue_unlock(cardholder_for(charge))
    end

    # A charge was marked as having no/lost receipt (also a resolution).
    def on_no_or_lost_receipt(charge)
      charge.materialize_card_locking! if charge.is_a?(HcbCode) && charge.card_locking_chargeable?
      enqueue_unlock(cardholder_for(charge))
    end

    # The cardholder whose cards lock is always the person on the charge, never
    # the person who uploaded the receipt: an org teammate may upload it, or an
    # unauthenticated email-link upload has no user at all (receipt.user is
    # nullable). Resolve through the Stripe card association (the reliable path
    # materialize_card_locking! also uses), not HcbCode#author, whose cardholder
    # lookup keys off a stripe_transaction JSON field that is not always present.
    # A non-card-charge receiptable has no cardholder, so this is nil and
    # enqueue_unlock is a no-op.
    def cardholder_for(charge)
      return unless charge.is_a?(HcbCode)

      charge.stripe_card&.stripe_cardholder&.user
    end

    def enqueue_unlock(user, notify_progress: false)
      return unless user.present?

      # High priority: a cardholder who just uploaded is often standing at a
      # register waiting for the card to work, and the copy promises "seconds."
      # Don't leave the unlock on the :low queue where a backlog can stall it.
      User::UpdateCardLockingJob
        .set(queue: :critical)
        .perform_later(user:, unlock_only: true, notify_progress:)
    end
  end
end
