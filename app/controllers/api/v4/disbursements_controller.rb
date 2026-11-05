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

        # Plain transfers stay the default so existing clients don't change.
        transfer_type = params[:transfer_type].presence || "transfer"

        if transfer_type == "repayment"
          authorize @disbursement, :repay?
          # Looked up among the destination's own expenses, so an id from
          # elsewhere is treated as missing rather than revealed.
          repaid_hcb_code = HcbCode.find_by_public_id(params[:repaid_transaction_id]) if params[:repaid_transaction_id].present?
          repaid_ledger_item = Repayment.unrepaid_ledger_items(@destination_event).find_by(id: repaid_hcb_code.ledger_item_id) if repaid_hcb_code&.ledger_item_id
        end

        @disbursement = DisbursementService::Create.new(
          source_event_id: @source_event.id,
          destination_event_id: @destination_event.id,
          name: params[:name],
          amount: Money.from_cents(params[:amount_cents]),
          requested_by_id: current_user.id,
          fronted: Disbursement.frontable?(source_event: @source_event, destination_event: @destination_event, requested_by: current_user),
          transfer_type:,
          repaid_ledger_item_id: repaid_ledger_item&.id,
          # Repayments categorize both sides deliberately, so they're manual.
          category_assignment_strategy: transfer_type == "transfer" ? "automatic" : "manual"
        ).run

        render :show, status: :created, location: api_v4_transaction_path(@disbursement)
      end

      require_oauth2_scope "transfers:write", :create

    end
  end
end
