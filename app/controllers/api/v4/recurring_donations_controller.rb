# frozen_string_literal: true

module Api
  module V4
    class RecurringDonationsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:index]
      before_action :set_recurring_donation, only: [:show]

      def index
        authorize @event, :show_in_v4?

        recurring_donations = @event.recurring_donations.includes(:event).order(created_at: :desc)

        recurring_donations = recurring_donations.where(stripe_status: params[:status]) if params[:status].present?

        @recurring_donations = paginate_cursor(recurring_donations.to_a, &:public_id)
      end

      def show
        authorize @recurring_donation.event, :show_in_v4?
      end

      private

      def set_recurring_donation
        @recurring_donation = RecurringDonation.find_by_public_id!(params[:id])
      end

    end
  end
end
