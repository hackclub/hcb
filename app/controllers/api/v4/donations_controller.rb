# frozen_string_literal: true

module Api
  module V4
    class DonationsController < ApplicationController
      include SetEvent
      include ApplicationHelper

      before_action :set_api_event, only: [:index, :create]
      before_action :require_trusted_oauth_app!, only: [:payment_intent]

      def index
        authorize @event, :show_in_v4?

        @recurring_donations = @event.recurring_donations.order(created_at: :asc)

        all_past_donations = @event.donations
                                   .where(aasm_state: params[:status] || [:in_transit, :deposited, :refunded])
                                   .order(created_at: :desc)
                                   .to_a

        @total_count = all_past_donations.length
        @past_donations = paginate_donations(all_past_donations)

        @total_cents = @event.donations.succeeded_and_not_refunded.sum(:amount)
        @monthly_cents = @event.recurring_donations.active.sum(:amount)
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
                                   anonymous: !!params[:anonymous],
                                   tax_deductible: params[:tax_deductible].nil? || params[:tax_deductible],
                                   fee_covered: !!params[:fee_covered] && @event.config.cover_donation_fees
                                 })

        authorize @donation

        @donation.save!

        render "show", status: :created
      end

      private

      def paginate_donations(donations)
        limit = params[:limit]&.to_i || 25
        if limit > 100
          return render json: { error: "invalid_operation", messages: "Limit is capped at 100. '#{params[:limit]}' is invalid." }, status: :bad_request
        end

        start_index = if params[:after]
                        index = donations.index { |d| d.public_id == params[:after] }
                        if index.nil?
                          return render json: { error: "invalid_operation", messages: "After parameter '#{params[:after]}' not found" }, status: :bad_request
                        end

                        index + 1
                      else
                        0
                      end

        @has_more = donations.length > start_index + limit
        donations.slice(start_index, limit)
      end

      public

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
