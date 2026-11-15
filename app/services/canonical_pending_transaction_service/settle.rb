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
        copy_splits!
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

    def sync_transaction_category!
      return unless @canonical_transaction.category.nil?
      return if @canonical_pending_transaction.category.nil?

      mapping = @canonical_pending_transaction.category_mapping

      @canonical_transaction.create_category_mapping!(
        category: mapping.category,
        assignment_strategy: mapping.assignment_strategy,
      )
    end

    # Splits keep their amounts when the settled amount is larger (a tip), so
    # what's left of the transaction absorbs the increase. When it's smaller,
    # they're cut down to fit, since a transaction can't be split past its
    # amount.
    def copy_splits!
      return if @canonical_transaction.splits.exists?
      # A second capture of the same pending transaction would double them up
      return if @canonical_pending_transaction.canonical_transactions.where.not(id: @canonical_transaction.id).exists?

      left = @canonical_transaction.amount_cents
      @canonical_pending_transaction.splits.each do |split|
        amount_cents = split.amount_cents.clamp(*[0, left].sort)
        next if amount_cents.zero?

        @canonical_transaction.splits.create!(amount_cents:, memo: split[:memo], category: split.category, repayment_allocation: split.repayment_allocation)
        left -= amount_cents
      end
    end

  end
end
