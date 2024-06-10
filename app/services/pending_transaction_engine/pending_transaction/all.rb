# frozen_string_literal: true

module PendingTransactionEngine
  module PendingTransaction
    class All
      def initialize(event_id:, search: nil, tag_id: nil, minimum_amount: nil, maximum_amount: nil, hack_club_hq: false)
        @event_id = event_id
        @search = search
        @tag_id = tag_id
        @minimum_amount = minimum_amount
        @maximum_amount = maximum_amount
        @hack_club_hq = hack_club_hq
      end

      def run
        canonical_pending_transactions
      end

      private

      def event
        @event ||= @event_id ? Event.find(@event_id) : nil
      end

      def canonical_pending_event_mappings
        if @hack_club_hq
          @canonical_pending_event_mappings ||= CanonicalPendingEventMapping.joins(:event).where(event: {category: :hack_club_hq}, subledger_id: nil)
        else 
          @canonical_pending_event_mappings ||= CanonicalPendingEventMapping.where(event_id: event.id, subledger_id: nil)
        end
      end

      def canonical_pending_transactions
        @canonical_pending_transactions ||=
          begin
            included_local_hcb_code_associations = [:receipts, :comments, :canonical_transactions, { canonical_pending_transactions: [:canonical_pending_declined_mapping] }]
            included_local_hcb_code_associations << :tags if Flipper.enabled?(:transaction_tags_2022_07_29, event)
            cpts = CanonicalPendingTransaction.includes(:raw_pending_stripe_transaction,
                                                        local_hcb_code: included_local_hcb_code_associations)
                                              .unsettled
                                              .where(id: canonical_pending_event_mappings.pluck(:canonical_pending_transaction_id))
                                              .order("canonical_pending_transactions.date desc, canonical_pending_transactions.id desc")

            if @tag_id
              cpts =
                cpts.joins("LEFT JOIN hcb_codes ON hcb_codes.hcb_code = canonical_pending_transactions.hcb_code")
                    .joins("LEFT JOIN hcb_codes_tags ON hcb_codes_tags.hcb_code_id = hcb_codes.id")
                    .where("hcb_codes_tags.tag_id = ?", @tag_id)
            end

            if @minimum_amount
              cpts = cpts.where("ABS(canonical_pending_transactions.amount_cents) >= #{@minimum_amount.cents}")
            end

            if @maximum_amount
              cpts = cpts.where("ABS(canonical_pending_transactions.amount_cents) <= #{@maximum_amount.cents}")
            end

            if event&.can_front_balance?
              cpts = cpts.not_fronted
            end

            cpts = cpts.search_memo(@search) if @search.present?
            cpts
          end
      end

    end
  end
end
