# frozen_string_literal: true

module Api
  module V4
    # Marks a transaction as a repayment of another on the same organization's
    # ledger. Repayment transfers are made through transfers.
    class RepaymentsController < ApplicationController
      include SetEvent

      before_action :set_api_event
      before_action :set_transaction

      # Transactions this one could be marked as a repayment with.
      def candidates
        authorize @ledger_item, :mark_repayment?

        hcb_codes = Repayment.match_candidates(@ledger_item, current_user).includes(:hcb_code).order(datetime: :desc).filter_map(&:hcb_code)
        @transactions = resolve_engines(paginate_cursor(hcb_codes, &:public_id))

        render "api/v4/transactions/index"
      end

      require_oauth2_scope "ledgers:read", :candidates

      def create
        authorize @ledger_item, :mark_repayment?

        # `transaction_id` is this transaction, from the path.
        other = HcbCode.find_by_public_id!(params.require(:other_transaction_id)).ledger_item
        raise ActiveRecord::RecordNotFound if other.nil?

        RepaymentService::Mark.new(ledger_item: @ledger_item, other_ledger_item_hashid: other.hashid, created_by: current_user).run

        @transaction = resolve_engine(@hcb_code.reload)
        render "api/v4/transactions/show", status: :created
      end

      require_oauth2_scope "transactions:write", :create

      private

      def set_transaction
        @hcb_code = HcbCode.find_by_public_id!(params[:transaction_id])
        raise ActiveRecord::RecordNotFound unless @hcb_code.events.include?(@event)
        raise ActiveRecord::RecordNotFound if @hcb_code.ledger_item.nil?

        # A transfer's sender links it through the recipient's incoming side,
        # as on the web.
        @ledger_item = Repayment.markable_item(@hcb_code.ledger_item)
        raise ArgumentError, "This transfer hasn't been sent yet." if @ledger_item.nil?
      end

    end
  end
end
