# frozen_string_literal: true

module Api
  module V4
    class TransactionsController < ApplicationController
      include SetEvent
      include ApplicationHelper

      before_action :set_api_event, only: [:update, :memo_suggestions]
      skip_after_action :verify_authorized, only: [:missing_receipt]

      def index
        @event = Event.find_by_public_id(params[:id]) || Event.find_by!(slug: params[:id]) # we don't use set_api_event here because it is passed as id in the url

        authorize @event, :show_in_v4?

        @settled_transactions = TransactionGroupingEngine::Transaction::All.new(**filters).run
        @pending_transactions = PendingTransactionEngine::PendingTransaction::All.new(**filters).run

        type_results = ::EventsController.filter_transaction_type(params[:type], settled_transactions: @settled_transactions, pending_transactions: @pending_transactions)
        @settled_transactions = type_results[:settled_transactions]
        @pending_transactions = type_results[:pending_transactions]

        @total_count = @pending_transactions.count + @settled_transactions.count
        @transactions = paginate_transactions(@pending_transactions + @settled_transactions)

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

      def show
        @hcb_code = authorize HcbCode.find_by_public_id!(params[:id])

        if params[:event_id]
          set_api_event
          raise ActiveRecord::RecordNotFound if !@hcb_code.events.include?(@event)
        else
          @event = @hcb_code.events.find { |e| e.users.include?(current_user) } || @hcb_code.events.first
        end
      end

      def missing_receipt
        user_hcb_code_ids = current_user.stripe_cards.flat_map { |card| card.local_hcb_codes.pluck(:id) }
        user_hcb_codes = HcbCode.where(id: user_hcb_code_ids)
        hcb_codes_missing_ids = user_hcb_codes.select do |hcb_code|
          hcb_code.events.any? { |event| hcb_code.missing_receipt?(event) }
        end.map(&:id)

        @hcb_codes = HcbCode.where(id: hcb_codes_missing_ids).order(created_at: :desc)

        @total_count = @hcb_codes.size
        @hcb_codes = paginate_hcb_codes(@hcb_codes)
      end

      def update
        @hcb_code = authorize HcbCode.find_by_public_id(params[:id])

        if params.key? :memo
          @hcb_code.canonical_transactions.each { |ct| ct.update!(custom_memo: params[:memo]) }
          @hcb_code.canonical_pending_transactions.each { |cpt| cpt.update!(custom_memo: params[:memo]) }
        end

        render "show"
      end

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

      private

      def paginate_transactions(transactions)
        limit = params[:limit]&.to_i || 25
        start_index = if params[:after]
                        transactions.index { |tx| tx.local_hcb_code.public_id == params[:after] } + 1
                      else
                        0
                      end
        @has_more = transactions.length > start_index + limit

        transactions.slice(start_index, limit)
      end

      def filters
        filter_params = params.fetch(:filters, {}).permit(
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

        return {
          event_id: @event.id,
          search: filter_params[:search].presence,
          tag_id: filter_params[:tag_id].presence,
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
