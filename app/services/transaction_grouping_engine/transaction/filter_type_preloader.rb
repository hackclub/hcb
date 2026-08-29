# frozen_string_literal: true

module TransactionGroupingEngine
  module Transaction
    # Preloads associations that `EventsController.filter_transaction_type`
    # reads on each settled row. Without this, each lambda walks
    # `t.local_hcb_code.<predicate>?` (and, for some types, deeper lazy
    # lookups) once per row — an N+1 that takes seconds on large orgs.
    #
    # Mutates the passed-in transactions in place. No-op when `type` is blank.
    class FilterTypePreloader
      def initialize(settled_transactions:, type:)
        @settled_transactions = settled_transactions
        @type = type
      end

      def run!
        return if @type.blank? || @settled_transactions.none?

        preload_local_hcb_code!
        preload_disbursements! if @type == "hcb_transfer"
        preload_canonical_transactions! if @type == "card_charge"
      end

      private

      def preload_local_hcb_code!
        @hcb_codes_by_code = ::HcbCode.where(hcb_code: @settled_transactions.map(&:hcb_code)).index_by(&:hcb_code)
        @settled_transactions.each { |t| t.local_hcb_code = @hcb_codes_by_code[t.hcb_code] }
      end

      # `hcb_transfer` reads `outgoing_disbursement` / `incoming_disbursement`,
      # both of which are otherwise unmemoized `Disbursement.find_by` calls.
      def preload_disbursements!
        disbursement_hcb_codes = @hcb_codes_by_code.values.select { |hc| hc.outgoing_disbursement? || hc.incoming_disbursement? }
        disbursements_by_id = ::Disbursement.where(id: disbursement_hcb_codes.map(&:hcb_i2)).index_by(&:id)
        disbursement_hcb_codes.each do |hc|
          disbursement = disbursements_by_id[hc.hcb_i2.to_i]
          hc.outgoing_disbursement = disbursement&.outgoing_disbursement if hc.outgoing_disbursement?
          hc.incoming_disbursement = disbursement&.incoming_disbursement if hc.incoming_disbursement?
        end
      end

      # `card_charge` reads `t.raw_stripe_transaction`, which walks
      # `ct -> transaction_source` — both lazy lookups per row.
      def preload_canonical_transactions!
        ct_ids = @settled_transactions.flat_map(&:canonical_transaction_ids)
        cts_by_id = ::CanonicalTransaction.where(id: ct_ids).index_by(&:id)
        stripe_source_ids = cts_by_id.values.select { |ct| ct.transaction_source_type == ::RawStripeTransaction.name }.map(&:transaction_source_id)
        rsts_by_id = ::RawStripeTransaction.where(id: stripe_source_ids).index_by(&:id)
        cts_by_id.each_value do |ct|
          ct.raw_stripe_transaction = rsts_by_id[ct.transaction_source_id] if ct.transaction_source_type == ::RawStripeTransaction.name
        end
        @settled_transactions.each do |t|
          t.canonical_transactions = t.canonical_transaction_ids.filter_map { |id| cts_by_id[id] }
                                      .sort_by { |ct| [ct.date, ct.id] }.reverse
        end
      end

    end
  end
end
