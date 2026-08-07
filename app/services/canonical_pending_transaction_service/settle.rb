# frozen_string_literal: true

module CanonicalPendingTransactionService
  class Settle
    def initialize(canonical_transaction:, canonical_pending_transaction:)
      @canonical_transaction = canonical_transaction
      @canonical_pending_transaction = canonical_pending_transaction
    end

    def run!
      ActiveRecord::Base.transaction do
        CanonicalPendingSettledMapping.create!(
          canonical_transaction: @canonical_transaction,
          canonical_pending_transaction: @canonical_pending_transaction
        )

        copy_custom_memo!

        sync_transaction_category!
      end

      if @canonical_transaction.amount_cents < 0 && @canonical_pending_transaction.raw_pending_stripe_transaction && (@canonical_pending_transaction.amount_cents != @canonical_transaction.amount_cents)
        CanonicalPendingTransactionMailer.with(
          canonical_pending_transaction_id: @canonical_pending_transaction.id,
          canonical_transaction_id: @canonical_transaction.id,
        ).notify_settled.deliver_later

        spending_control = @canonical_transaction.stripe_card.active_spending_control
        if spending_control.present?
          SpendingControlService.check_low_balance(spending_control, @canonical_transaction.local_hcb_code)
        end
      end
    end

    private

    def copy_custom_memo!
      memo = @canonical_pending_transaction.custom_memo

      # Only copy a memo that exists — routing a nil through
      # `update_custom_memo!` would clear the memo on every record in the group,
      # including the ledger item's.
      return unless @canonical_transaction.custom_memo.nil? && memo.present?

      # `custom_memo` is mirrored onto the transaction's ledger item, which caches
      # its `memo` from that copy. `HcbCode#update_custom_memo!` is the only
      # writer that keeps both sides in sync; fall back to the ledger item, and
      # only write the column directly when the transaction has neither.
      if (hcb_code = @canonical_transaction.local_hcb_code)
        hcb_code.update_custom_memo!(memo)
      elsif (ledger_item = @canonical_transaction.ledger_item)
        ledger_item.update_custom_memo!(memo)
      else
        @canonical_transaction.update!(custom_memo: memo)
      end

      # `CanonicalPendingSettledMapping` hands the canonical transaction over to
      # the pending transaction's ledger item once this transaction commits. When
      # the two HCB codes differ — several settle paths pair a pending transaction
      # with a still-ungrouped HCB-000 canonical transaction — that item sits in
      # another group and the write above never reaches it.
      @canonical_pending_transaction.ledger_item&.update_custom_memo!(memo)
    end

    def sync_transaction_category!
      return unless @canonical_transaction.category.nil?
      return if @canonical_pending_transaction.category.nil?

      mapping = @canonical_pending_transaction.category_mapping

      @canonical_transaction.create_category_mapping!(
        category: mapping.category,
        assignment_strategy: mapping.assignment_strategy,
      )
    end

  end
end
