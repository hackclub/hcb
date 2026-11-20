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
    #
    # Receipts attach to all sorts of records; only a Ledger::Item can be a
    # charge. Reloaded so the resolution reads the receipt_count the Receipt's
    # touch recounted in the database, not whatever this copy last loaded.
    def on_receipt_upsert(receipt)
      charge = charge_for(receipt.receiptable)
      charge.materialize_card_locking! if charge&.card_locking_chargeable?
      enqueue_unlock(charge&.card_locking_cardholder, notify_progress: true)
    end

    # A receipt was destroyed. Only deleting the charge's last receipt matters:
    # it leaves the charge missing a receipt again, so its 7-day countdown
    # restarts from now rather than the charge counting as overdue the moment the
    # receipt is gone. Deleting one of several receipts, or a receipt on a charge
    # that is also marked no/lost, leaves the charge resolved and its deadline
    # untouched.
    def on_receipt_destroy(receipt)
      charge = charge_for(receipt.receiptable)
      charge.restart_card_locking_countdown! if charge&.card_locking_chargeable? && charge.missing_receipt?
      enqueue_unlock(charge&.card_locking_cardholder)
    end

    # A charge was marked as having no/lost receipt (also a resolution). Called
    # from the item's own column hook (CardLocking::ChargeBehavior).
    def on_no_or_lost_receipt(charge)
      charge.materialize_card_locking! if charge.card_locking_chargeable?
      enqueue_unlock(charge.card_locking_cardholder)
    end

    def charge_for(receiptable)
      receiptable.reload if receiptable.is_a?(::Ledger::Item)
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
