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

        @settled_transactions = TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).run
        @pending_transactions = PendingTransactionEngine::PendingTransaction::All.new(event_id: @event.id).run

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

    end
  end
end
