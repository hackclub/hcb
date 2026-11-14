# frozen_string_literal: true

module Api
  module V4
    class TransactionsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:update, :memo_suggestions]
      skip_after_action :verify_authorized, only: [:missing_receipt]

      def index
        @event = Event.find_by_public_id(params[:id]) || Event.find_by!(slug: params[:id]) # we don't use set_api_event here because it is passed as id in the url

        authorize @event, :show_in_v4?

        return index_from_ledger if ledger_engine?

        @settled_transactions = TransactionGroupingEngine::Transaction::All.new(**filters).run
        @pending_transactions = PendingTransactionEngine::PendingTransaction::All.new(**filters).run

        TransactionGroupingEngine::Transaction::FilterTypePreloader.new(
          settled_transactions: @settled_transactions,
          type: params[:type]
        ).run!

        type_results = ::EventsController.filter_transaction_type(params[:type], settled_transactions: @settled_transactions, pending_transactions: @pending_transactions)
        @settled_transactions = type_results[:settled_transactions]
        @pending_transactions = type_results[:pending_transactions]

        @total_count = @pending_transactions.count + @settled_transactions.count
        cursor_hcb_code = HcbCode.find_by_public_id(params[:after])&.hcb_code if params[:after].present?
        @transactions = paginate_cursor(@pending_transactions + @settled_transactions) { |tx| tx.hcb_code == cursor_hcb_code ? params[:after] : nil }

        if @transactions.any?
          page_settled = @transactions.select { |tx| tx.is_a?(CanonicalTransactionGrouped) }
          page_pending = @transactions.select { |tx| tx.is_a?(CanonicalPendingTransaction) }

          if page_settled.any?
            TransactionGroupingEngine::Transaction::AssociationPreloader.new(transactions: page_settled, event: @event).run!
          end

          if page_pending.any?
            PendingTransactionEngine::PendingTransaction::AssociationPreloader.new(pending_transactions: page_pending, event: @event).run!
          end
        end
      end

      require_oauth2_scope "ledgers:read", :index

      def show
        @hcb_code = authorize HcbCode.find_by_public_id!(params[:id])

        if params[:event_id]
          set_api_event
          raise ActiveRecord::RecordNotFound if !@hcb_code.events.include?(@event)
        else
          @event = @hcb_code.events.find { |e| e.users.include?(current_user) } || @hcb_code.events.first
        end

        @transaction = resolve_engine(@hcb_code)
      end

      require_oauth2_scope "ledgers:read", :show # maybe this should be transactions:read

      def missing_receipt
        user_hcb_code_ids = current_user.stripe_cards.flat_map { |card| card.local_hcb_codes.pluck(:id) }
        user_hcb_codes = HcbCode.where(id: user_hcb_code_ids)
        hcb_codes_missing_ids = user_hcb_codes.select do |hcb_code|
          hcb_code.events.any? { |event| hcb_code.missing_receipt?(event) }
        end.map(&:id)

        @hcb_codes = HcbCode.where(id: hcb_codes_missing_ids).order(created_at: :desc)

        @transactions = resolve_engines(paginate_cursor(@hcb_codes, &:public_id))
      end

      require_oauth2_scope "ledgers:read", :missing_receipt

      def update
        @hcb_code = authorize HcbCode.find_by_public_id(params[:id])

        ActiveRecord::Base.transaction do
          if params.key? :memo
            @hcb_code.update_custom_memo!(params[:memo])
          end

          if params.key? :tag_ids
            tags = Array(params[:tag_ids]).map { |id| Tag.find_by_public_id!(id) }

            tags.each do |tag|
              authorize tag, :toggle_tag?
              raise Pundit::NotAuthorizedError unless @hcb_code.events.include?(tag.event)
            end

            @hcb_code.tags = tags
            @hcb_code.save!
          end
        end

        @transaction = resolve_engine(@hcb_code)

        render "show"
      end

      require_oauth2_scope "transactions:write", :update

      def memo_suggestions
        @hcb_code = authorize HcbCode.find_by_public_id(params[:id]), :update?

        @suggested_memos = ::HcbCodeService::SuggestedMemos.new(hcb_code: @hcb_code, event: @event).run.first(4)
      end

      def mark_no_receipt
        @hcb_code = HcbCode.find_by_public_id!(params[:id])
        authorize @hcb_code, :mark_no_or_lost?, policy_class: ReceiptablePolicy

        @hcb_code.no_or_lost_receipt!
        render json: { message: "Transaction marked as no/lost receipt" }, status: :ok
      end

      require_oauth2_scope "receipts:write", :mark_no_receipt

      private

      LEDGER_PENDING_RANK = "(CASE WHEN ledger_items.status = 'pending' THEN 0 ELSE 1 END)"

      def index_from_ledger
        limit = pagination_limit
        items = ledger_query.execute(ledgers: [@event.ledger]).where.associated(:hcb_code)
        @total_count = items.unscope(:order).count

        if params[:after].present?
          cursor = items.find_by(id: HcbCode.find_by_public_id(params[:after])&.ledger_item_id)
          raise ArgumentError, "After parameter '#{params[:after]}' not found" if cursor.nil?

          # Keyset on Ledger::Query's ordering: pending first, then datetime, created_at, id descending.
          items = items.where(
            "#{LEDGER_PENDING_RANK} > :rank OR (#{LEDGER_PENDING_RANK} = :rank AND (ledger_items.datetime, ledger_items.created_at, ledger_items.id) < (:datetime, :created_at, :id))",
            rank: cursor.pending? ? 0 : 1, datetime: cursor.datetime, created_at: cursor.created_at, id: cursor.id
          )
        end

        page = items.preload(hcb_code: [
                               :event, :tags,
                               { canonical_transactions: :canonical_event_mapping },
                               { canonical_pending_transactions: [:canonical_pending_event_mapping, :canonical_pending_declined_mapping, :raw_pending_stripe_transaction] }
                             ]).limit(limit + 1).to_a
        @has_more = page.size > limit
        @transactions = page.first(limit)
      end

      # `order_by` is ignored: Ledger::Query has a fixed ordering.
      def ledger_query
        f = filter_params
        query = []

        query << { memo: { "$search": f[:search] } } if f[:search].present?
        query << { amount_cents: { "$gt": 0 } } if f[:revenue].present?
        query << { amount_cents: { "$lt": 0 } } if f[:expenses].present?

        if f[:minimum_amount].present?
          minimum = Money.from_amount(f[:minimum_amount].to_f).cents
          query << { "$or": [{ amount_cents: { "$gte": minimum } }, { amount_cents: { "$lte": -minimum } }] }
        end

        if f[:maximum_amount].present?
          # Multiple operators on one field are AND-combined: |amount| <= max
          maximum = Money.from_amount(f[:maximum_amount].to_f).cents
          query << { amount_cents: { "$lte": maximum, "$gte": -maximum } }
        end

        if f[:missing_receipts].present?
          query << { receipt_count: { "$eq": 0 } }
          query << { receipt_required: { "$eq": true } }
          query << { marked_no_or_lost_receipt_at: { "$eq": nil } }
        end

        query << { datetime: { "$gte": f[:start_date].to_date } } if f[:start_date].present?
        # Whole-day inclusive end bound, matching the old engine
        query << { datetime: { "$lt": f[:end_date].to_date.next_day } } if f[:end_date].present?

        if f[:user_id].present?
          user = @event.users.find_by_public_id(f[:user_id])
          query << { author: { "$eq": user&.slug || f[:user_id] } }
        end

        if f[:tag_id].present?
          tag = Tag.find_by_public_id(f[:tag_id])
          query << { tag: { "$eq": tag&.id } }
        end

        query << { category: { "$eq": f[:category] } } if f[:category].present?
        query << { merchant: { "$eq": f[:merchant] } } if f[:merchant].present?
        if SetLedgerFilters::TYPE_PREDICATES.key?(params[:type])
          query << { linked_object_type: SetLedgerFilters::TYPE_PREDICATES[params[:type]] }
        elsif params[:type] == "refund"
          # Ledger has no refund flag; approximate as an incoming card charge.
          query << { linked_object_type: { "$eq": "CardCharge" } }
          query << { amount_cents: { "$gt": 0 } }
        end

        query << SetLedgerFilters::VISIBLE
        Ledger::Query.new({ "$and": query })
      end

      def filter_params
        @filter_params ||= params.fetch(:filters, {}).permit(
          :search,
          :tag_id,
          :expenses,
          :revenue,
          :minimum_amount,
          :maximum_amount,
          :start_date,
          :end_date,
          :user_id,
          :missing_receipts,
          :category,
          :merchant,
          :order_by
        )
      end

      def filters
        return {
          event_id: @event.id,
          search: filter_params[:search].presence,
          tag_id: filter_params[:tag_id].present? ? Tag.find_by_public_id(filter_params[:tag_id])&.id : nil,
          expenses: filter_params[:expenses].presence,
          revenue: filter_params[:revenue].presence,
          minimum_amount: filter_params[:minimum_amount].presence ? Money.from_amount(filter_params[:minimum_amount].to_f) : nil,
          maximum_amount: filter_params[:maximum_amount].presence ? Money.from_amount(filter_params[:maximum_amount].to_f) : nil,
          start_date: filter_params[:start_date].presence,
          end_date: filter_params[:end_date].presence,
          user: filter_params[:user_id] ? @event.users.find_by_public_id(filter_params[:user_id]) : nil,
          missing_receipts: filter_params[:missing_receipts].present?,
          category: filter_params[:category].presence,
          merchant: filter_params[:merchant].presence,
          order_by: filter_params[:order_by].presence
        }
      end

    end
  end
end
