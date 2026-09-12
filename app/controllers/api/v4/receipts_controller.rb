# frozen_string_literal: true

module Api
  module V4
    class ReceiptsController < ApplicationController
      def index
        receiptable_id = params[:receiptable_id] || params[:transaction_id]

        unless receiptable_id.present?
          # No receiptable specified: return the current user's receipt bin.
          skip_authorization
          return @receipts = Receipt.in_receipt_bin.includes(:user).where(user: current_user)
        end

        receiptable = PublicIdentifiable.find_by_public_id(receiptable_id)
        raise ActiveRecord::RecordNotFound if receiptable.nil?

        @receipts = case receiptable
                    when HcbCode, ::Reimbursement::Expense
                      authorize receiptable, :show?
                      receiptable.receipts.includes(:user)
                    when User
                      raise Pundit::NotAuthorizedError unless receiptable == current_user

                      skip_authorization
                      Receipt.in_receipt_bin.includes(:user).where(user: receiptable)
                    else
                      raise ActiveRecord::RecordNotFound
                    end
      end

      require_oauth2_scope "receipts:read", :index

      def create
        if params[:transaction_id].present?
          @hcb_code = HcbCode.find_by_public_id!(params[:transaction_id])
          authorize @hcb_code, :upload?, policy_class: ReceiptablePolicy
        else
          skip_authorization
        end
        @receipt = Receipt.create!(file: params[:file], receiptable: @hcb_code, user: current_user, upload_method: :api)

        render "show", status: :created
      end

      require_oauth2_scope "receipts:write", :create

      def destroy
        @receipt = Receipt.find_by_public_id(params[:id]) || Receipt.find_by_hashid!(params[:id]) # TODO: remove hash ID after mobile app update
        authorize @receipt

        @receipt.destroy!
        render json: { message: "Receipt successfully deleted" }, status: :ok
      end

      require_oauth2_scope "receipts:write", :destroy

    end
  end
end
