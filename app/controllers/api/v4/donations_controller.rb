# frozen_string_literal: true

module Api
  module V4
    class DonationsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:index, :create]
      before_action :set_donation, only: [:show, :payment_intent]
      before_action :require_trusted_oauth_app!, only: [:create, :payment_intent]

      def index
        authorize @event, :show_in_v4?

        donations = @event.donations.not_pending.order(created_at: :desc)

        donations = donations.filter_by_visible_state(params[:status], context: @event) if params[:status].present?

        @donations = paginate_cursor(donations.to_a, &:public_id)

        if @expand.include?(:stats)
          @total_cents = @event.donations.not_pending.succeeded_and_not_refunded.sum(:amount)
        end
      end

      def show
        authorize @donation
      end

      def create
        amount = params[:amount_cents]
        if params[:fee_covered] && @event.config.cover_donation_fees
          amount /= (1 - @event.revenue_fee).ceil
        end

        @donation = Donation.new({
                                   amount:,
                                   event_id: @event.id,
                                   collected_by_id: current_user.id,
                                   in_person: true,
                                   name: params[:name].presence,
                                   email: params[:email].presence,
                                   message: params[:message].presence,
                                   anonymous: !!params[:anonymous],
                                   tax_deductible: params[:tax_deductible].nil? || params[:tax_deductible],
                                   fee_covered: !!params[:fee_covered] && @event.config.cover_donation_fees
                                 })

        authorize @donation

        @donation.save!

        render "show", status: :created
      end

      def payment_intent
        authorize @donation

        render json: { payment_intent_id: @donation.stripe_payment_intent_id, client_secret: @donation.stripe_client_secret }
      end

      private

      def set_donation
        @donation = Donation.find_by_public_id!(params[:id])
      end

    end
  end
end
