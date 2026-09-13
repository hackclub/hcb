# frozen_string_literal: true

module Api
  module V5
    class DisbursementsController < ApplicationController
      include Api::V5::TransferCreation
      include Api::V5::ScopedResource

      scoped_resource Disbursement, organization_scope: :either_end, preload: [:event]

      def create
        source = find_organization!(params[:organization_id])
        destination = find_organization!(params[:to_organization_id])

        authorize Disbursement.new(source_event: source, destination_event: destination)

        @record = DisbursementService::Create.new(
          source_event_id: source.id,
          destination_event_id: destination.id,
          name: params[:name],
          amount: Money.from_cents(params[:amount_cents]),
          requested_by_id: current_user.id,
          fronted: source.plan.front_disbursements_enabled?
        ).run

        render :show, status: :created
      end

      require_oauth2_scope "transfers:write", :create
    end
  end
end
