# frozen_string_literal: true

module StripeAuthorizationService
  class CreateFromWebhookForced
    def initialize(stripe_transaction_id:)
      @stripe_transaction_id = stripe_transaction_id
    end

    def run
      t = ::Stripe::Issuing::Transaction.retrieve(@stripe_transaction_id)

      ActiveRecord::Base.transaction do
        # 1. idempotent import into raw_stripe_transactions (settled engine)
        rst = ::RawStripeTransaction.find_or_initialize_by(stripe_transaction_id: t[:id]).tap do |r|
          r.stripe_transaction = t
          r.amount_cents = t[:amount]
          r.date_posted = Time.at(t[:created])
          r.stripe_authorization_id = t[:authorization]
          r.unique_bank_identifier = "STRIPEISSUING1"
        end
        rst.save!

        # 2. idempotent hash
        ph = ::TransactionEngine::HashedTransactionService::PrimaryHash.new(
          unique_bank_identifier: rst.unique_bank_identifier,
          date: rst.date_posted.strftime("%Y-%m-%d"),
          amount_cents: rst.amount_cents,
          memo: rst.memo.to_s.upcase
        ).run

        ht = ::HashedTransaction.find_or_initialize_by(raw_stripe_transaction_id: rst.id).tap do |h|
          h.primary_hash = ph[0]
          h.primary_hash_input = ph[1]
        end
        ht.save!

        # 3. idempotent create settled canonical transaction
        # after_create_commit on CanonicalTransaction handles event mapping automatically
        next if ht.canonical_hashed_mapping.present?

        ::CanonicalTransaction.create!(
          date: ht.date,
          memo: ht.memo,
          amount_cents: ht.amount_cents,
          canonical_hashed_mappings: [CanonicalHashedMapping.new(hashed_transaction: ht)],
          transaction_source: rst
        )
      end

      TopupStripeJob.perform_later
    end

  end
end
