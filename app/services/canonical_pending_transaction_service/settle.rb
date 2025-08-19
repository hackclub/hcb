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

  end
end
