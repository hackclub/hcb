# frozen_string_literal: true

module PendingTransactionEngine
  module PendingTransaction
    class All
      def initialize(event_id:, search: nil, tag_id: nil, minimum_amount: nil, maximum_amount: nil, start_date: nil, end_date: nil, user: nil, missing_receipts: false)
        @event_id = event_id
        @search = search
        @tag_id = tag_id
        @minimum_amount = minimum_amount
        @maximum_amount = maximum_amount
        @start_date = start_date
        @end_date = end_date
        @user = user
        @missing_receipts = missing_receipts
      end

      def run
        canonical_pending_transactions
      end

      private

      def event
        @event ||= Event.find(@event_id)
      end

      def canonical_pending_event_mappings
        @canonical_pending_event_mappings ||= CanonicalPendingEventMapping.where(event_id: event.id, subledger_id: nil)
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

            if @missing_receipts
              cpts =
                cpts.joins("LEFT JOIN hcb_codes ON hcb_codes.hcb_code = canonical_pending_transactions.hcb_code")
                    .joins("LEFT JOIN receipts ON receipts.receiptable_id = hcb_codes.id AND receipts.receiptable_type = 'HcbCode'")
                    .where("receipts.id IS NULL AND hcb_codes.marked_no_or_lost_receipt_at is NULL AND canonical_pending_transactions.amount_cents <= 0")
            end

            if @user
              cpts =
                cpts.joins("LEFT JOIN raw_pending_stripe_transactions on raw_pending_stripe_transactions.id = canonical_pending_transactions.raw_pending_stripe_transaction_id")
                    .where("raw_pending_stripe_transactions.stripe_transaction->>'cardholder' = '#{@user&.stripe_cardholder&.stripe_id}'")
            end

            if @minimum_amount
              cpts = cpts.where("ABS(canonical_pending_transactions.amount_cents) >= #{@minimum_amount.cents}")
            end

            if @maximum_amount
              cpts = cpts.where("ABS(canonical_pending_transactions.amount_cents) <= #{@maximum_amount.cents}")
            end

            if @start_date
              cpts = cpts.where("canonical_pending_transactions.date >= cast('#{@start_date}' as date)")
            end

            if @end_date
              cpts = cpts.where("canonical_pending_transactions.date <= cast('#{@end_date}' as date)")
            end

            if event.can_front_balance?
              cpts = cpts.not_fronted
            end

            cpts = cpts.search_memo(@search) if @search.present?
            cpts
          end
      end

    end
  end
end
