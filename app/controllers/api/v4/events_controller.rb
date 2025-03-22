# frozen_string_literal: true

module Api
  module V4
    class EventsController < ApplicationController
      skip_after_action :verify_authorized, only: [:index]

      def index
        @events = current_user.events.not_hidden.includes(:users).order("organizer_positions.created_at DESC")
      end

      def show
        @event = authorize Event.find_by_public_id(params[:id]) || Event.friendly.find(params[:id])
      end

      def transactions
        @event = Event.find_by_public_id(params[:id]) || Event.friendly.find(params[:id])
        authorize @event, :show?

        @settled_transactions = TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).run
        TransactionGroupingEngine::Transaction::AssociationPreloader.new(transactions: @settled_transactions, event: @event).run!

        @pending_transactions = PendingTransactionEngine::PendingTransaction::All.new(event_id: @event.id).run
        PendingTransactionEngine::PendingTransaction::AssociationPreloader.new(pending_transactions: @pending_transactions, event: @event).run!

        type_results = ::EventsController.filter_transaction_type(params[:type], settled_transactions: @settled_transactions, pending_transactions: @pending_transactions)
        @settled_transactions = type_results[:settled_transactions]
        @pending_transactions = type_results[:pending_transactions]

        @total_count = @pending_transactions.count + @settled_transactions.count
        @transactions = paginate_transactions(@pending_transactions + @settled_transactions)
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

    end
  end
end
