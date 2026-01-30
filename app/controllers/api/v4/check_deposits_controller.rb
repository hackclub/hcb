# frozen_string_literal: true

module Api
  module V4
    class CheckDepositsController < ApplicationController
      include SetEvent

      before_action :set_api_event

      def index
        authorize @event
        @check_deposits = @event.check_deposits.order(created_at: :desc)

        render :index, status: :ok
      end

      def show
        @check_deposit = CheckDeposit.find_by_public_id!(params[:id])
        authorize @check_deposit

        render :show, status: :ok
      end

      def create
        check_deposit_params = params.permit(:front, :back, :amount_cents).merge(created_by: current_user)

        @check_deposit = @event.check_deposits.build(check_deposit_params)

        authorize @check_deposit

        @check_deposit.save!

        render :show, status: :created
      end

    end
  end
end
