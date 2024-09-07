# frozen_string_literal: true

module TransactionGroupingEngine
  module Transaction
    class AssociationPreloader
      def initialize(transactions:, event:)
        @transactions = transactions
        @event = event
      end

      def run!
        preload_associations!
      end

      def preload_associations!
        hcb_code_codes = @transactions.map(&:hcb_code)
        included_models = [
          :receipts,
          :comments,
          { canonical_transactions: [:canonical_event_mapping, :transaction_source] },
          { canonical_pending_transactions: [:event, :canonical_pending_declined_mapping, :raw_pending_stripe_transaction] },
          { reimbursement_expense_payout: { expense: [:report] } }
        ]
        included_models << :tags if Flipper.enabled?(:transaction_tags_2022_07_29, @event)
        hcb_code_objects = HcbCode
                           .includes(included_models)
                           .where(hcb_code: hcb_code_codes)
        hcb_code_by_code = hcb_code_objects.index_by(&:hcb_code)

        # Query for CanonicalTransactions associated with hcb_codes because this can be the superset of
        # canonical_transactions associated with @transactions due to pagination
        # https://github.com/hackclub/hcb/pull/2453#discussion_r848110917
        # However, we still need to OR with CanonicalTransactions by id because hcb codes are lazily attached
        # If hcb codes are ever eagerly attached to CanonicalTransactions instead, we can remove the OR
        canonical_transactions = CanonicalTransaction
                                 .where(hcb_code: hcb_code_codes)
                                 .or(
                                   CanonicalTransaction.where(id: @transactions.flat_map(&:canonical_transaction_ids))
                                 )

        canonical_transactions_by_id = canonical_transactions.index_by(&:id)
        canonical_transaction_ids = canonical_transactions.pluck(:id)

        canonical_pending_transactions_by_id = CanonicalPendingTransaction.where(hcb_code: hcb_code_codes).index_by(&:id)

        hack_club_fees_by_canonical_transaction_id = Fee
                                                     .includes(:canonical_event_mapping)
                                                     .where(canonical_event_mappings: { canonical_transaction_id: canonical_transaction_ids })
                                                     .hack_club_fee
                                                     .index_by { |fee| fee.canonical_event_mapping.canonical_transaction_id }

        hashed_transactions_by_canonical_transaction_id = HashedTransaction
                                                          .includes(:canonical_hashed_mapping, :raw_stripe_transaction)
                                                          .where(canonical_hashed_mappings: { canonical_transaction_id: canonical_transaction_ids })
                                                          .group_by { |ht| ht.canonical_hashed_mapping.canonical_transaction_id }

        raw_stripe_transactions_by_id = RawStripeTransaction.find(canonical_transactions.where(transaction_source_type: RawStripeTransaction.name).pluck(:transaction_source_id)).index_by(&:id)

        canonical_transactions.each do |ct|
          ct.fee_payment = hack_club_fees_by_canonical_transaction_id[ct.id].present?
          ct.raw_stripe_transaction = raw_stripe_transactions_by_id[ct.transaction_source_id] if ct.transaction_source_type == "RawStripeTransaction"

          hashed_transactions = hashed_transactions_by_canonical_transaction_id[ct.id] || []
          Airbrake.notify("There was more (or less) than 1 hashed_transaction for canonical_transaction: #{ct.id}") if hashed_transactions.length > 1
          ct.hashed_transaction = hashed_transactions.first
        end

        # We have to look up StripeCardholders after attaching HashedTransaction (which preloads raw_stripe_transaction)
        # or we will trigger an N+1
        stripe_ids = canonical_transactions.filter_map do |ct|
          if ct.raw_stripe_transaction
            ct.raw_stripe_transaction.stripe_transaction["cardholder"]
          end
        end
        stripe_cardholders_by_stripe_id = ::StripeCardholder.includes(:user).where(stripe_id: stripe_ids).index_by(&:stripe_id)

        canonical_transactions.each do |ct|
          if ct.raw_stripe_transaction
            ct.stripe_cardholder = stripe_cardholders_by_stripe_id[ct.raw_stripe_transaction.stripe_transaction["cardholder"]]
          end
        end

        @transactions.each do |t|
          t.canonical_transactions = canonical_transactions_by_id
                                     .slice(*t.canonical_transaction_ids)
                                     .values
                                     .sort { |ct1, ct2| self.class.compare_date_id_descending(ct1, ct2) }
          t.canonical_pending_transactions = canonical_pending_transactions_by_id
                                             .slice(*t.canonical_pending_transaction_ids)
                                             .values
                                             .sort { |pt1, pt2| self.class.compare_date_id_descending(pt1, pt2) }

          t.local_hcb_code = hcb_code_by_code[t.hcb_code]
        end
      end

      # comparator that can be used in Array#sort for canonical_transactions
      # https://ruby-doc.org/core-2.7.5/Array.html#method-i-sort
      def self.compare_date_id_descending(ct1, ct2)
        # date in descending order
        if ct2.date > ct1.date
          1
        elsif ct2.date < ct1.date
          -1
        else
          # if dates are equal, id in descending order
          ct2.id <=> ct1.id
        end
      end

    end
  end
end
