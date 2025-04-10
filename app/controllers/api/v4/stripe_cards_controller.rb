# frozen_string_literal: true

module Api
  module V4
    class StripeCardsController < ApplicationController
      def index
        if params[:event_id].present?
          @event = authorize(Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id]), :card_overview?)
          @stripe_cards = @event.stripe_cards.includes(:user, :event).order(created_at: :desc)
        else
          skip_authorization
          @stripe_cards = current_user.stripe_cards.includes(:user, :event).order(created_at: :desc)
        end
      end

      def show
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])
      end

      def transactions
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        @hcb_codes = @stripe_card.hcb_codes.order(created_at: :desc)
        @hcb_codes = @hcb_codes.select(&:missing_receipt?) if params[:missing_receipts] == "true"

        @total_count = @hcb_codes.size
        @has_more = false # TODO: implement pagination
      end

      def create
        event = authorize(Event.find(params[:stripe_card][:organization_id]))
        authorize event, :create_stripe_card?, policy_class: EventPolicy

        sc = params.require(:stripe_card).permit(
          :organization_id,
          :card_type,
          :stripe_shipping_name,
          :stripe_shipping_address_city,
          :stripe_shipping_address_line1,
          :stripe_shipping_address_postal_code,
          :stripe_shipping_address_line2,
          :stripe_shipping_address_state,
          :stripe_shipping_address_country,
          :stripe_card_personalization_design_id,
          :birthday
        )

        if current_user.birthday.nil?
          user_params = sc.slice("birthday(1i)", "birthday(2i)", "birthday(3i)")
          current_user.update(user_params)
        end

        return render json: { error: "internal_server_error" }, status: :internal_server_error if current_user.birthday.nil?
        return render json: { error: "internal_server_error" }, status: :internal_server_error unless sc[:stripe_shipping_address_country] == "US"

        new_card = ::StripeCardService::Create.new(
          current_user:,
          current_session: {ip: request.remote_ip},
          event_id: event.id,
          card_type: sc[:card_type],
          stripe_shipping_name: sc[:stripe_shipping_name],
          stripe_shipping_address_city: sc[:stripe_shipping_address_city],
          stripe_shipping_address_state: sc[:stripe_shipping_address_state],
          stripe_shipping_address_line1: sc[:stripe_shipping_address_line1],
          stripe_shipping_address_line2: sc[:stripe_shipping_address_line2],
          stripe_shipping_address_postal_code: sc[:stripe_shipping_address_postal_code],
          stripe_shipping_address_country: sc[:stripe_shipping_address_country],
          stripe_card_personalization_design_id: sc[:stripe_card_personalization_design_id] || StripeCard::PersonalizationDesign.common.first&.id
        ).run

        return render json: { error: "internal_server_error" }, status: :internal_server_error if new_card.nil?

        @stripe_card = new_card
        render :show
        
        rescue => e
          notify_airbrake(e)
          render json: { error: "internal_server_error" }, status: :internal_server_error
      end

      def update
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        if params[:status] == "frozen" && !@stripe_card.frozen?
          @stripe_card.freeze!
        end

        render "show"
      end

      def ephemeral_keys
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        return render json: { error: "not_authorized" }, status: :forbidden unless current_token.application&.trusted?
        return render json: { error: "invalid_operation", messages: ["card must be virtual"] }, status: :bad_request unless @stripe_card.virtual?

        @ephemeral_key = @stripe_card.ephemeral_key(nonce: params[:nonce])

        ahoy.track "Card details shown", stripe_card_id: @stripe_card.id, user_id: current_user.id, oauth_token_id: current_token.id

        render json: { ephemeralKeySecret: @ephemeral_key.secret, stripe_id: @stripe_card.stripe_id }

      rescue Stripe::InvalidRequestError
        return render json: { error: "internal_server_error" }, status: :internal_server_error

      end

    end
  end
end
