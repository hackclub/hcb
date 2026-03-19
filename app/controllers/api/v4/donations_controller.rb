# frozen_string_literal: true

module Api
  module V4
    class DonationsController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:create]
      before_action :require_trusted_oauth_app!, only: [:payment_intent]

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
                                   anonymous: !!params[:anonymous],
                                   tax_deductible: params[:tax_deductible].nil? || params[:tax_deductible],
                                   fee_covered: !!params[:fee_covered] && @event.config.cover_donation_fees
                                 })

        authorize @donation

        @donation.save!

        render "show", status: :created
      end

      def payment_intent
        amount = params[:amount_cents]
        if params[:fee_covered] && @event.config.cover_donation_fees
          amount /= (1 - @event.revenue_fee).ceil
        end

        payment_intent = StripeService::PaymentIntent.create({
                                                               amount:,
                                                               currency: "usd",
                                                               payment_method_types: ["card_present"],
                                                               capture_method: "automatic",
                                                               statement_descriptor: "HCB",
                                                               statement_descriptor_suffix: StripeService::StatementDescriptor.format(@event.short_name, as: :suffix),
                                                               metadata: { donation: true, event_id: @event.id },
                                                             })

        render json: { payment_intent_id: payment_intent.id }, status: :created
      end

    end
  end
end
