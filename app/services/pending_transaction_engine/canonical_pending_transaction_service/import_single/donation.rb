# frozen_string_literal: true

module PendingTransactionEngine
  module CanonicalPendingTransactionService
    module ImportSingle
      class Donation
        def initialize(raw_pending_donation_transaction:)
          @raw_pending_donation_transaction = raw_pending_donation_transaction
        end

        def run
          return existing_canonical_pending_transaction if existing_canonical_pending_transaction

          attrs = {
            date: @raw_pending_donation_transaction.date,
            memo: @raw_pending_donation_transaction.memo,
            amount_cents: @raw_pending_donation_transaction.amount_cents,
            raw_pending_donation_transaction_id: @raw_pending_donation_transaction.id,
            fronted: true
          }
          cpt = ::CanonicalPendingTransaction.create!(attrs)

          TransactionCategoryService.new(model: cpt).set!(slug: "donations", assignment_strategy: "automatic")

          cpt
        end

        private

        def existing_canonical_pending_transaction
          @existing_canonical_pending_transaction ||= ::CanonicalPendingTransaction.where(raw_pending_donation_transaction_id: @raw_pending_donation_transaction.id).first
        end

      end
    end
  end
end
