# frozen_string_literal: true

module Api
  module V4
    class CheckDepositsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:create]

      def create
        check_deposit_params = params.permit(:front, :back, :amount_cents).merge(created_by: current_user)

        @check_deposit = @event.check_deposits.build(check_deposit_params)

        authorize @check_deposit

        begin
          @check_deposit.save!
        rescue ActiveRecord::RecordInvalid
          return render json: { error: "invalid_operation", messages: @check_deposit.errors.full_messages }, status: :unprocessable_entity
        end

        render :show, status: :created
      end

    end
  end
end
