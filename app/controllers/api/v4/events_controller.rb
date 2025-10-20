# frozen_string_literal: true

module Api
  module V4
    class EventsController < ApplicationController
      before_action :set_event, except: [:index]
      skip_after_action :verify_authorized, only: [:index]

      def index
        @events = current_user.events.not_hidden.includes(:users).order("organizer_positions.created_at DESC")
      end

      def show
        authorize @event, :show_in_v4?
      end

      require_oauth2_scope "organizations:read", :show

      def transactions
        authorize @event, :show_in_v4?

        @settled_transactions = TransactionGroupingEngine::Transaction::All.new(filters).run
        TransactionGroupingEngine::Transaction::AssociationPreloader.new(transactions: @settled_transactions, event: @event).run!

        @pending_transactions = PendingTransactionEngine::PendingTransaction::All.new(filters).run
        PendingTransactionEngine::PendingTransaction::AssociationPreloader.new(pending_transactions: @pending_transactions, event: @event).run!

        type_results = ::EventsController.filter_transaction_type(params[:type], settled_transactions: @settled_transactions, pending_transactions: @pending_transactions)
        @settled_transactions = type_results[:settled_transactions]
        @pending_transactions = type_results[:pending_transactions]

        @total_count = @pending_transactions.count + @settled_transactions.count
        @transactions = paginate_transactions(@pending_transactions + @settled_transactions)
      end

      def followers
        authorize @event, :show_in_v4?
        @followers = @event.followers
      end

      require_oauth2_scope "event_followers", :followers

      private

      def set_event
        @event = Event.find_by_public_id(params[:id]) || Event.find_by!(slug: params[:id])
      end

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
        filter_params = params.require(:filters).permit(
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
