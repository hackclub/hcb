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
      charge = charge_for(receipt.receiptable)
      charge.materialize_card_locking! if charge&.card_locking_chargeable?
      enqueue_unlock(charge&.card_locking_cardholder, notify_progress: true)
    end

    # A receipt was destroyed. Only deleting the charge's last receipt matters:
    # it leaves the charge outstanding again, so its 7-day countdown restarts
    # from now rather than the charge counting as overdue the moment the receipt
    # is gone. Deleting one of several receipts, or a receipt on a charge that is
    # also marked no/lost, leaves the charge resolved and its deadline untouched.
    # Reloaded so the check reads the receipts left in the database, not an
    # association loaded before the destroy.
    def on_receipt_destroy(receipt)
      charge = charge_for(receipt.receiptable)
      if charge&.card_locking_chargeable? && !charge.reload.card_locking_resolved?
        charge.restart_card_locking_countdown!
      end
      enqueue_unlock(charge&.card_locking_cardholder)
    end

    # A charge was marked as having no/lost receipt (also a resolution).
    def on_no_or_lost_receipt(receiptable)
      charge = charge_for(receiptable)
      charge.materialize_card_locking! if charge&.card_locking_chargeable?
      enqueue_unlock(charge&.card_locking_cardholder)
    end

    # Card-locking state lives on Ledger::Item (CardLocking::ChargeBehavior). A
    # no/lost mark can still arrive through the transaction's HCB code
    # (ReceiptablesController accepts one), so a code resolves to its item. Nil
    # for every other receiptable, so the callers above no-op for them.
    def charge_for(receiptable)
      case receiptable
      when ::Ledger::Item then receiptable
      when HcbCode then receiptable.ledger_item
      end
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
