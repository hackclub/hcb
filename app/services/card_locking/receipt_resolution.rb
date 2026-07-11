# frozen_string_literal: true

module CardLocking
  # Keeps a charge's persisted receipt timing in sync when a receipt is attached,
  # removed, or the charge is marked no/lost, then triggers an unlock recompute.
  # Uploading a receipt can only ever unlock, so the recompute is unlock-only.
  module ReceiptResolution
    module_function

    # A receipt was created or updated. Materialize synchronously so the unlock
    # job sees the resolution, then recompute the lock.
    def on_receipt_upsert(receipt)
      charge = receipt.receiptable
      charge.materialize_card_locking! if charge.is_a?(HcbCode) && charge.card_locking_chargeable?
      enqueue_unlock(receipt.user)
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
      enqueue_unlock(receipt.user)
    end

    # A charge was marked as having no/lost receipt (also a resolution).
    def on_no_or_lost_receipt(charge)
      charge.materialize_card_locking! if charge.is_a?(HcbCode) && charge.card_locking_chargeable?
      enqueue_unlock(charge.try(:author) || charge.try(:user))
    end

    def enqueue_unlock(user)
      User::UpdateCardLockingJob.perform_later(user:, unlock_only: true) if user.present?
    end
  end
end
