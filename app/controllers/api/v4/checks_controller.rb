# frozen_string_literal: true

module Api
  module V4
    class ChecksController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:index, :create]

      def index
        authorize @event, :transfers_in_v4?
        @checks = @event.increase_checks.order(created_at: :desc)
      end

      def show
        @check = authorize IncreaseCheck.find_by_public_id!(params[:id])
      end

      def create
        check_params = params.require(:check).permit(
          :memo,
          :amount_cents,
          :payment_for,
          :recipient_name,
          :recipient_email,
          :address_line1,
          :address_line2,
          :address_city,
          :address_state,
          :address_zip,
          :send_email_notification,
          :file
        )

        @check = @event.increase_checks.build(
          check_params.except(:file, :amount_cents).merge(
            amount: check_params[:amount_cents],
            user: current_user
          )
        )

        authorize @check

        if @check.amount > SudoModeHandler::THRESHOLD_CENTS
          return render json: {
            error: "invalid_operation",
            messages: ["Checks above the sudo mode threshold of #{ApplicationController.helpers.render_money(SudoModeHandler::THRESHOLD_CENTS)} are not allowed via API."]
          }, status: :bad_request
        end

        @check.save!

        if check_params[:file]
          ::ReceiptService::Create.new(
            uploader: current_user,
            attachments: check_params[:file],
            upload_method: :check_api,
            receiptable: @check.local_hcb_code
          ).run!
        end

        render :show, status: :created
      end

    end
  end
end
