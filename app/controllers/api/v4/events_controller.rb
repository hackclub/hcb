# frozen_string_literal: true

module Api
  module V4
    class EventsController < ApplicationController
      before_action :set_event, except: [:index, :create]
      skip_after_action :verify_authorized, only: [:index]

      def index
        if params[:event_id]
          event = Event.find_by_public_id(params[:event_id]) || Event.find_by!(slug: params[:event_id])
          authorize event, :sub_organizations?

          @events = event.subevents.includes(:users).order("organizer_positions.created_at DESC")
        else
          @events = current_user.events.not_hidden.includes(:users).order("organizer_positions.created_at DESC")
        end
      end

      def create
        parent_event = Event.find_by_public_id(params[:event_id]) || Event.find_by!(slug: params[:event_id])
        authorize parent_event, :create_sub_organization?


        if params[:email].blank?
          render json: { error: "invalid_operation", messages: "Organizer email is required" }, status: :bad_request
        end

        @event = ::EventService::Create.new(
          name: params[:name],
          emails: [params[:email]],
          cosigner_email: params[:cosigner_email],
          is_signee: true,
          country: params[:country],
          point_of_contact_id: parent_event.point_of_contact_id,
          invited_by: current_user,
          is_public: parent_event.is_public,
          plan: parent_event.config.subevent_plan.presence,
          risk_level: parent_event.risk_level,
          parent_event: parent_event,
          scoped_tags: params[:scoped_tags]
        ).run

        render :show, status: :created, location: api_v4_event_path(@event)
      end

      def show
        authorize @event, :show_in_v4?
      end

      require_oauth2_scope "organizations:read", :show

      def transactions
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
