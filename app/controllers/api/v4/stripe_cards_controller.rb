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

      def update
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        if params[:status] == "frozen"
          if @stripe_card.canceled?
            return render json: { error: "Card has been cancelled, it can't be frozen" }, status: :unprocessable_entity
          end

          @stripe_card.freeze!
        elsif params[:status] == "active"
          if params[:last4].blank?
            return render json: { error: "Last four digits are required" }, status: :unprocessable_entity
          end

          # Find the correct card based on it's last4
          card = current_user.stripe_cardholder&.stripe_cards&.find_by(last4: params[:last4])
          if card.nil? || card.id != @stripe_card.id
            return render json: { error: "Last four digits are incorrect" }, status: :unprocessable_entity
          end

          if @stripe_card.canceled?
            return render json: { error: "Card has been cancelled, it can't be activated." }, status: :unprocessable_entity
          end

          if @stripe_card.initially_activated?
            if @stripe_card.created_at < Date.new(2024, 2, 22)
              @stripe_card.defrost! unless @stripe_card.stripe_status == "active"
              return render json: { success: "Card activated!" }
            else
              return render json: { error: "Card already activated" }, status: :unprocessable_entity
            end
          end
          # If this replaces another card, attempt to cancel the old card.
          if @stripe_card.replacement_for
            suppress(Stripe::InvalidRequestError) do
              @stripe_card.replacement_for.cancel!
            end
          end

          @stripe_card.update(initially_activated: true)
          @stripe_card.defrost!

          render json: { success: "Card activated!" }
        end
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
