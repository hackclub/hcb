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

        if @canonical_transaction.custom_memo.nil?
          @canonical_transaction.custom_memo = @canonical_pending_transaction.custom_memo
          @canonical_transaction.save!
        end

        sync_transaction_category!
      end

      # The caller may be mid-transaction — a Stripe capture settles inside the
      # transaction that creates its CanonicalTransaction — and ActiveJob does
      # not defer enqueues to commit (enqueue_after_transaction_commit is
      # false), so hold these until the mapping is durable: the mailer reads
      # the records back in another process, and a low-balance check run
      # against uncommitted state would read a balance without the capture in
      # it. Runs immediately when there is no surrounding transaction.
      ActiveRecord.after_all_transactions_commit { notify_settled! }
    end

    private

    def notify_settled!
      return unless @canonical_transaction.amount_cents < 0
      return unless @canonical_pending_transaction.raw_pending_stripe_transaction
      return if @canonical_pending_transaction.amount_cents == @canonical_transaction.amount_cents

      CanonicalPendingTransactionMailer.with(
        canonical_pending_transaction_id: @canonical_pending_transaction.id,
        canonical_transaction_id: @canonical_transaction.id,
      ).notify_settled.deliver_later

      spending_control = @canonical_transaction.stripe_card.active_spending_control
      if spending_control.present?
        SpendingControlService.check_low_balance(spending_control, @canonical_transaction.local_hcb_code)
      end
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
