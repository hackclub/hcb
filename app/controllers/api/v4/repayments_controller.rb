# frozen_string_literal: true

module Api
  module V4
    # Marks a transaction as a repayment of another on the same organization's
    # ledger, or undoes it. Repayment transfers are made through transfers.
    class RepaymentsController < ApplicationController
      include SetEvent

      before_action :set_api_event
      before_action :set_transaction

      # Transactions this one could be marked as a repayment with.
      def candidates
        authorize @ledger_item, :mark_repayment?

        hcb_codes = Repayment.match_candidates(@ledger_item).includes(:hcb_code).order(datetime: :desc).filter_map(&:hcb_code)
        @transactions = paginate_cursor(hcb_codes, &:public_id)

        render "api/v4/transactions/index"
      end

      require_oauth2_scope "ledgers:read", :candidates

      def create
        authorize @ledger_item, :mark_repayment?

        # `transaction_id` is this transaction, from the path.
        other = HcbCode.find_by_public_id!(params.require(:other_transaction_id)).ledger_item
        raise ActiveRecord::RecordNotFound if other.nil?

        RepaymentService::Mark.new(ledger_item: @ledger_item, other_ledger_item_hashid: other.hashid, created_by: current_user).run

        @hcb_code.reload
        render "api/v4/transactions/show", status: :created
      end

      require_oauth2_scope "transactions:write", :create

      def destroy
        authorize @ledger_item, :unmark_repayment?

        repayment = @ledger_item.marked_repayment
        raise ArgumentError, "This transaction isn't marked as a repayment." if repayment.nil?

        RepaymentService::Unmark.new(repayment:).run

        @hcb_code.reload
        render "api/v4/transactions/show"
      end

      require_oauth2_scope "transactions:write", :destroy

      private

      def set_transaction
        @hcb_code = HcbCode.find_by_public_id!(params[:transaction_id])
        raise ActiveRecord::RecordNotFound unless @hcb_code.events.include?(@event)

        @ledger_item = @hcb_code.ledger_item
        raise ActiveRecord::RecordNotFound if @ledger_item.nil?
      end

    end
  end
end
