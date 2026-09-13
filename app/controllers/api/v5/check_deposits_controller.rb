# frozen_string_literal: true

module Api
  module V5
    class CheckDepositsController < ApplicationController
      include Api::V5::TransferCreation
      include Api::V5::ScopedResource

      scoped_resource CheckDeposit, organization_scope: :event, preload: [:event]

      def create
        event = find_organization!(params[:organization_id])

        @record = event.check_deposits.build(
          permitted_attributes(CheckDeposit.new(event:)).merge(created_by: current_user)
        )
        authorize @record
        @record.save!

        render :show, status: :created
      end

      require_oauth2_scope "transfers:write", :create
    end
  end
end
