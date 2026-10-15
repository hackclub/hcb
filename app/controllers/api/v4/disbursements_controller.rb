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

        # Defaults to a plain transfer, which is all this endpoint made before
        # transfer types existed.
        transfer_type = params[:transfer_type].presence || "transfer"

        if transfer_type == "repayment"
          authorize @disbursement, :repay?
          repaid_ledger_item = HcbCode.find_by_public_id(params[:repaid_transaction_id])&.ledger_item
        end

        @disbursement = DisbursementService::Create.new(
          source_event_id: @source_event.id,
          destination_event_id: @destination_event.id,
          name: params[:name],
          amount: Money.from_cents(params[:amount_cents]),
          requested_by_id: current_user.id,
          fronted: @source_event.plan.front_disbursements_enabled?,
          transfer_type:,
          repaid_ledger_item_id: repaid_ledger_item&.id,
          category_assignment_strategy: transfer_type == "transfer" ? "automatic" : "manual"
        ).run

        render :show, status: :created, location: api_v4_transaction_path(@disbursement)
      end

      require_oauth2_scope "transfers:write", :create

    end
  end
end
