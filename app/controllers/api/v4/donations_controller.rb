# frozen_string_literal: true

module Api
  module V4
    class DonationsController < ApplicationController
      include SetEvent
      include ApplicationHelper

      before_action :set_api_event, only: [:index, :create]
      before_action :set_donation, only: [:payment_intent]
      before_action :require_trusted_oauth_app!, only: [:payment_intent]

      def index
        authorize @event, :show_in_v4?

        @recurring_donations = @event.recurring_donations.order(created_at: :asc)

        all_past_donations = @event.donations
                                   .where(aasm_state: params[:status] || [:in_transit, :deposited, :refunded])
                                   .order(created_at: :desc)
                                   .to_a

        @past_donations = paginate_cursor(all_past_donations, &:public_id)

        if expand?(:stats)
          @total_cents = @event.donations.succeeded_and_not_refunded.sum(:amount)
          @monthly_cents = @event.recurring_donations.active.sum(:amount)
        end
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
        amount = @donation.amount
        if @donation.fee_covered
          amount /= (1 - @donation.event.revenue_fee).ceil
        end

        payment_intent = StripeService::PaymentIntent.create({
                                                               amount:,
                                                               currency: "usd",
                                                               payment_method_types: ["card_present"],
                                                               capture_method: "automatic",
                                                               statement_descriptor: "HCB",
                                                               statement_descriptor_suffix: StripeService::StatementDescriptor.format(@donation.event.short_name, as: :suffix),
                                                               metadata: { donation: true, donation_id: @donation.id, event_id: @donation.event.id },
                                                             })

        render json: { payment_intent_id: payment_intent.id, client_secret: payment_intent.client_secret }, status: :created
      end

      private

      def set_donation
        @donation = Donation.find(params[:id])
      end

    end
  end
end
