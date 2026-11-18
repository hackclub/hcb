# frozen_string_literal: true

module Api
  module V4
    class AchTransfersController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:create]

      def create
        permitted_params = [
          :routing_number,
          :account_number,
          :recipient_email,
          :bank_name,
          :recipient_name,
          :amount_money,
          :payment_for,
          :send_email_notification,
          :invoiced_at,
          :file,
        ]

        if can_admin?(:write)
          permitted_params << :scheduled_on
        end

        ach_transfer_params = params.require(:ach_transfer).permit(*permitted_params)

        @ach_transfer = @event.ach_transfers.build(ach_transfer_params.except(:file).merge(creator: current_user))

        authorize @ach_transfer

        if @ach_transfer.amount > SudoModeHandler::THRESHOLD_CENTS
          # Don't let API submit ACH transfers above sudo mode threshold
          return render json: { error: "invalid_operation", messages: ["ACH transfers above the sudo mode threshold of #{ApplicationController.helpers.render_money(SudoModeHandler::THRESHOLD_CENTS)} are not allowed."] }, status: :bad_request
        end


        @ach_transfer.save!

        # The receipt belongs on the transfer's ledger item, which only exists
        # once the pending transaction created with the transfer commits, so
        # attach it after the save rather than in a transaction around both.
        if ach_transfer_params[:file]
          ::ReceiptService::Create.new(
            uploader: current_user,
            attachments: Array(ach_transfer_params[:file]),
            upload_method: :api,
            receiptable: @ach_transfer.reload_ledger_item # the association was cached as nil while the transfer's pending transaction was being created
          ).run!
        end

        render :show, status: :created
      end

    end
  end
end
