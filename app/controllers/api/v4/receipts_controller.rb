# frozen_string_literal: true

module Api
  module V4
    class ReceiptsController < ApplicationController
      def index
        if params[:transaction_id].present?
          @hcb_code = HcbCode.find_by_public_id(params[:transaction_id])
          authorize @hcb_code, :show?
          @receipts = @hcb_code.receipts.includes(:user)
        else
          skip_authorization
          @receipts = Receipt.in_receipt_bin.includes(:user).where(user: current_user)
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
