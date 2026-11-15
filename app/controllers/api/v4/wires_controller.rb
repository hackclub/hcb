# frozen_string_literal: true

module Api
  module V4
    class WiresController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:index, :create]

      def index
        authorize @event, :transfers_in_v4?
        @wires = paginate_cursor(@event.wires.order(created_at: :desc).to_a, &:public_id)
      end

      def show
        @wire = authorize Wire.find_by_public_id!(params[:id])

        render :show, status: :ok
      end

      def create
        @wire = @event.wires.build(wire_params.except(:file).merge(user: current_user))

        authorize @wire

        if @wire.usd_amount_cents > SudoModeHandler::THRESHOLD_CENTS
          return render json: {
            error: "invalid_operation",
            messages: ["Wire transfers above the sudo mode threshold of #{ApplicationController.helpers.render_money(SudoModeHandler::THRESHOLD_CENTS)} are not allowed via API."]
          }, status: :bad_request
        end

        @wire.save!

        # The receipt is attached after the save commits: a transfer's ledger
        # item, which the receipt belongs on, is only assigned once its pending
        # transaction commits (see Receipt's before_validation).
        if wire_params[:file]
          ::ReceiptService::Create.new(
            uploader: current_user,
            attachments: Array(wire_params[:file]),
            upload_method: :api,
            receiptable: @wire.local_hcb_code
          ).run!
        end

        render :show, status: :created
      end

      private

      def wire_params
        params.require(:wire).permit(
          :memo,
          :amount_cents,
          :currency,
          :payment_for,
          :recipient_name,
          :recipient_email,
          :account_number,
          :bic_code,
          :recipient_country,
          :address_line1,
          :address_line2,
          :address_city,
          :address_state,
          :address_postal_code,
          :send_email_notification,
          :file,
          *Wire.recipient_information_accessors
        )
      end

    end
  end
end
