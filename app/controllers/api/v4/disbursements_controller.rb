# frozen_string_literal: true

module Api
  module V4
    class DisbursementsController < ApplicationController
      def create
        @source_event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])
        @destination_event = Event.find_by_public_id(params[:to_organization_id]) || Event.friendly.find(params[:to_organization_id])
        @disbursement = Disbursement.new(destination_event: @destination_event, source_event: @source_event)

        authorize @disbursement

        begin
          @disbursement = DisbursementService::Create.new(
            source_event_id: @source_event.id,
            destination_event_id: @destination_event.id,
            name: params[:name],
            amount: Money.from_cents(params[:amount_cents]),
            requested_by_id: current_user.id,
            skip_auto_approve: true,
          ).run
        rescue ArgumentError => e
          return render json: { error: "invalid_operation", messages: [e.message] }, status: :bad_request
        end

        render :show
      end

    end
  end
end
