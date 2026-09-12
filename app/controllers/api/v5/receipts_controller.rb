# frozen_string_literal: true

module Api
  module V5
    class ReceiptsController < ApplicationController
      # Two distinct lists behind one route, as in v4: the receipts on a given
      # transaction, or the caller's own Receipt Bin. The bin is a policy scope;
      # the transaction's receipts are reached through an authorized transaction.
      # v4 reached the bin via `skip_authorization`, which this replaces.
      after_action :verify_authorized, only: :index

      def index
        @receipts =
          if params[:transaction_id].present?
            # `skip_policy_scope` rather than dropping the after_action: the bin
            # branch below still has to prove it scoped, and skipping the
            # callback outright would excuse both.
            skip_policy_scope
            item = authorize Ledger::Item.find_by_public_id!(params[:transaction_id]), :show_any_attribute?
            item.receipts.includes(:user)
          else
            skip_authorization
            policy_scope(Receipt).in_receipt_bin.includes(:user)
          end

        @receipts = paginate_cursor(@receipts.to_a, &:public_id)
      end

      require_oauth2_scope "receipts:read", :index

      def create
        receiptable =
          if params[:transaction_id].present?
            authorize Ledger::Item.find_by_public_id!(params[:transaction_id]), :upload?, policy_class: ReceiptablePolicy
          else
            # No transaction means the Receipt Bin, which is the caller's own.
            skip_authorization
            nil
          end

        @receipt = Receipt.create!(file: params[:file], receiptable:, user: current_user, upload_method: :api)

        render :show, status: :created
      end

      require_oauth2_scope "receipts:write", :create

      def destroy
        receipt = authorize Receipt.find_by_public_id!(params[:id])
        receipt.destroy!

        render json: { message: "Receipt successfully deleted" }, status: :ok
      end

      require_oauth2_scope "receipts:write", :destroy
    end
  end
end
