# frozen_string_literal: true

module Api
  module V4
    class WiresController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:create]

      def create
        
        wire_params = params.require(:wire).permit(
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
          *Wire.recipient_information_accessors
        )
        
        @wire = @event.wires.build(wire_params.merge(user: current_user))

        authorize @wire

        if @wire.usd_amount_cents > SudoModeHandler::THRESHOLD_CENTS
          return render json: {
            error: "invalid_operation",
            messages: ["Wire transfers above the sudo mode threshold of #{ApplicationController.helpers.render_money(SudoModeHandler::THRESHOLD_CENTS)} are not allowed via API."]
          }, status: :bad_request
        end

        @wire.save!

        render :show, status: :created
      end

    end
  end
end
