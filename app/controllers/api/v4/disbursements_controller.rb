# frozen_string_literal: true

module Api
  module V4
    class DisbursementsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:create]

      def create
        @source_event = @event
        @destination_event = Event.find_by_public_id(params[:to_organization_id]) || Event.friendly.find(params[:to_organization_id])
        @disbursement = Disbursement.new(destination_event: @destination_event, source_event: @source_event)

        authorize @disbursement

        @disbursement = DisbursementService::Create.new(
          source_event_id: @source_event.id,
          destination_event_id: @destination_event.id,
          name: params[:name],
          amount: Money.from_cents(params[:amount_cents]),
          requested_by_id: current_user.id,
          fronted: @source_event.plan.front_disbursements_enabled?
        ).run

        render :show, status: :created, location: api_v4_transaction_path(@disbursement)
      end

    end
  end
end
