# frozen_string_literal: true

module Api
  module V4
    class ReceiptsController < ApplicationController
      def index
        @hcb_code = authorize HcbCode.find_by_public_id(params[:transaction_id]), :show?
        @receipts = @hcb_code.receipts.includes(:user)
      end

      def receipt_bin
        skip_authorization
        @receipts = Receipt.in_receipt_bin.includes(:user)
        render "index"
      end

      def create
        @hcb_code = HcbCode.find_by_public_id(params[:transaction_id])
        authorize @hcb_code, :upload?, policy_class: ReceiptablePolicy

        @receipt = Receipt.create!(file: params[:file], receiptable: @hcb_code, user: current_user, upload_method: :api)

        render "show"
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
