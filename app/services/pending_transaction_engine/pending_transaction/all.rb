# frozen_string_literal: true

module PendingTransactionEngine
  module PendingTransaction
    class All
      def initialize(event_id:, search: nil, tag_id: nil, minimum_amount: nil, maximum_amount: nil, start_date: nil, end_date: nil, revenue: false, expenses: false, user: nil, missing_receipts: false, category: nil, merchant: nil, order_by: :date, subledger: false, declined_or_reversed: false)
        @event_id = event_id
        @search = search
        @tag_id = tag_id&.to_i
        @minimum_amount = minimum_amount
        @maximum_amount = maximum_amount
        @start_date = start_date&.to_datetime
        @end_date = end_date&.to_datetime
        @revenue = revenue
        @expenses = expenses
        @user = user
        @missing_receipts = missing_receipts
        @category = category
        @merchant = merchant
        @order_by = order_by
        @subledger = subledger
        @declined_or_reversed = declined_or_reversed
      end

      def run
        canonical_pending_transactions
      end

      private

      def event
        @event ||= Event.find(@event_id)
      end

      def canonical_pending_event_mappings
        @canonical_pending_event_mappings ||= (@subledger ? CanonicalPendingEventMapping.where(event_id: event.id).where.not(subledger_id: nil) : CanonicalPendingEventMapping.where(event_id: event.id, subledger_id: nil))
      end

      def canonical_pending_transactions
        order_by_mapped_at = @order_by == :mapped_at

        @canonical_pending_transactions ||=
          begin
            included_local_hcb_code_associations = [:receipts, :comments, :canonical_transactions, { canonical_pending_transactions: [:canonical_pending_declined_mapping] }]
            included_local_hcb_code_associations << :tags
            cpts = CanonicalPendingTransaction.includes([:raw_pending_stripe_transaction,
                                                         order_by_mapped_at ? :canonical_pending_event_mapping : nil,
                                                         { local_hcb_code: included_local_hcb_code_associations }])
            if @declined_or_reversed
              cpts = cpts.declined
            else
              cpts = cpts.unsettled
            end

            cpts = cpts.where(id: canonical_pending_event_mappings.pluck(:canonical_pending_transaction_id))
                       .order("#{order_by_mapped_at ? "canonical_pending_event_mappings.created_at" : "canonical_pending_transactions.date"} desc, canonical_pending_transactions.id desc")

            if @user || @merchant
              cpts = cpts.joins("LEFT JOIN raw_pending_stripe_transactions on raw_pending_stripe_transactions.id = canonical_pending_transactions.raw_pending_stripe_transaction_id")
            end

            if @tag_id
              cpts =
                cpts.joins("LEFT JOIN hcb_codes ON hcb_codes.hcb_code = canonical_pending_transactions.hcb_code")
                    .joins("LEFT JOIN hcb_codes_tags ON hcb_codes_tags.hcb_code_id = hcb_codes.id")
                    .where("hcb_codes_tags.tag_id = ?", @tag_id)
            end


            if @expenses
              cpts = cpts.where("canonical_pending_transactions.amount_cents < 0")
            end

            if @revenue
              cpts = cpts.where("canonical_pending_transactions.amount_cents > 0")
            end

            if @missing_receipts
              cpts =
                cpts.joins("LEFT JOIN hcb_codes ON hcb_codes.hcb_code = canonical_pending_transactions.hcb_code")
                    .joins("LEFT JOIN receipts ON receipts.receiptable_id = hcb_codes.id AND receipts.receiptable_type = 'HcbCode'")
                    .where("receipts.id IS NULL AND hcb_codes.marked_no_or_lost_receipt_at is NULL AND canonical_pending_transactions.amount_cents <= 0")
            end

            if @user
              cpts = cpts.where("raw_pending_stripe_transactions.stripe_transaction->>'cardholder' = ?", @user&.stripe_cardholder&.stripe_id)
            end

            if @minimum_amount
              cpts = cpts.where("ABS(canonical_pending_transactions.amount_cents) >= ?", @minimum_amount.cents)
            end

            if @maximum_amount
              cpts = cpts.where("ABS(canonical_pending_transactions.amount_cents) <= ?", @maximum_amount.cents)
            end

            if @start_date
              cpts = cpts.where("canonical_pending_transactions.date >= cast(? as date)", @start_date)
            end

            if @end_date
              cpts = cpts.where("canonical_pending_transactions.date <= cast(? as date)", @end_date)
            end

            if @category
              cpts = cpts.joins("LEFT JOIN transaction_category_mappings tcm on canonical_pending_transactions.id = tcm.categorizable_id AND tcm.categorizable_type = 'CanonicalPendingTransaction'")
                         .where("tcm.transaction_category_id = ?", @category.id)
            end

            if @merchant
              cpts = cpts.where("raw_pending_stripe_transactions.stripe_transaction->'merchant_data'->>'network_id' = ?", @merchant)
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
