# frozen_string_literal: true

module CanonicalPendingTransactionService
  class Settle
    def initialize(canonical_transaction:, canonical_pending_transaction:)
      @canonical_transaction = canonical_transaction
      @canonical_pending_transaction = canonical_pending_transaction
    end

    def run!
      # A CPT should only ever settle to a single CT. Without this guard, two
      # callers racing (e.g. the real-time and nightly settle paths) could
      # each create a mapping for the same CPT to two different CTs.
      return false if @canonical_pending_transaction.settled?

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
    rescue ActiveRecord::RecordNotUnique
      # Lost the race to another caller settling the same CPT (or the same CT
      # settling twice) concurrently.
      false
    end

    private

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
