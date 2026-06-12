# frozen_string_literal: true

module Api
  module V4
    class ReceiptsController < ApplicationController
      def index
        @receipts = if params[:transaction_id].present?
                      @hcb_code = HcbCode.find_by_public_id(params[:transaction_id])
                      authorize @hcb_code, :show?
                      @hcb_code.receipts.includes(:user)
                    elsif params[:expense_id].present?
                      @expense = ::Reimbursement::Expense.find_by_public_id!(params[:expense_id])
                      authorize @expense, :show?
                      @expense.receipts.includes(:user)
                    else
                      skip_authorization
                      Receipt.in_receipt_bin.includes(:user).where(user: current_user)
                    end
      end

      def create
        if params[:transaction_id].present?
          @hcb_code = HcbCode.find_by_public_id(params[:transaction_id])
          authorize @hcb_code, :upload?, policy_class: ReceiptablePolicy
        else
          skip_authorization
        end
        @receipt = Receipt.create!(file: params[:file], receiptable: @hcb_code, user: current_user, upload_method: :api)

        render "show", status: :created
      end

      def destroy
        @receipt = Receipt.find(params[:id])
        authorize @receipt

        @receipt.destroy!
        render json: { message: "Receipt successfully deleted" }, status: :ok
      end


    end
  end
end
