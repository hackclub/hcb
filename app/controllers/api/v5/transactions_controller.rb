# frozen_string_literal: true

module Api
  module V5
    class TransactionsController < ApplicationController
      # `#index` is a projection of the transaction engines keyed on a single
      # organization, not a query over a table, so there is no relation for
      # `policy_scope` to filter. The organization is the object being
      # authorized — the request is "show me this organization's ledger" — and
      # each transaction's fields are then gated by HcbCodePolicy in turn.
      #
      # That is object-level authorization chosen deliberately, not the v4
      # `skip_authorization` pattern: the check still runs, and `show?` now
      # carries the transparency clause rather than a `*_in_v4?` fork, so a
      # transparent organization's ledger is public exactly as it is in v3.
      skip_after_action :verify_policy_scoped, only: :index
      after_action :verify_authorized, only: :index

      def index
        @event = authorize find_event, :show_any_attribute?

        settled = TransactionGroupingEngine::Transaction::All.new(**filters).run
        pending = PendingTransactionEngine::PendingTransaction::All.new(**filters).run

        TransactionGroupingEngine::Transaction::FilterTypePreloader.new(
          settled_transactions: settled,
          type: params[:type]
        ).run!

        type_results = ::EventsController.filter_transaction_type(params[:type], settled_transactions: settled, pending_transactions: pending)
        settled = type_results[:settled_transactions]
        pending = type_results[:pending_transactions]

        @total_count = pending.count + settled.count
        cursor_hcb_code = HcbCode.find_by_public_id(params[:after])&.hcb_code if params[:after].present?
        @transactions = paginate_cursor(pending + settled) { |tx| tx.hcb_code == cursor_hcb_code ? params[:after] : nil }

        preload_associations
      end

      require_oauth2_scope "ledgers:read", :index

      def show
        @hcb_code = authorize HcbCode.find_by_public_id!(params[:id]), :show_any_attribute?

        @event = @hcb_code.events.find { |e| current_user && e.users.include?(current_user) } || @hcb_code.events.first
      end

      require_oauth2_scope "ledgers:read", :show

      private

      def find_event
        id = params[:organization_id] || params[:event_id]

        Event.find_by_public_id(id) || Event.friendly.find(id)
      end

      def filters
        { event_id: @event.id }
      end

      def preload_associations
        return if @transactions.empty?

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
  end
end
