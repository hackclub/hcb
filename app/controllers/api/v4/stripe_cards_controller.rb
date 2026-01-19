# frozen_string_literal: true

module Api
  module V4
    class StripeCardsController < ApplicationController
      include SetEvent
      include ApplicationHelper

      def index
        if params[:event_id].present?
          set_api_event
          authorize @event, :card_overview_in_v4?
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

        @hcb_codes = @stripe_card.local_hcb_codes.order(created_at: :desc)
        @hcb_codes = @hcb_codes.select(&:missing_receipt?) if params[:missing_receipts] == "true"

        @total_count = @hcb_codes.size
        @hcb_codes = paginate_hcb_codes(@hcb_codes)
      end

      def create
        event = Event.find_by_public_id(params[:card][:organization_id]) || Event.friendly.find(params[:card][:organization_id])
        authorize event, :create_stripe_card?, policy_class: EventPolicy

        card = params.require(:card).permit(
          :organization_id,
          :card_type,
          :shipping_name,
          :shipping_address_city,
          :shipping_address_line1,
          :shipping_address_postal_code,
          :shipping_address_line2,
          :shipping_address_state,
          :shipping_address_country,
          :card_personalization_design_id
        )

        return render json: { error: "Birthday must be set before creating a card." }, status: :bad_request if current_user.birthday.nil?
        return render json: { error: "Cards can only be shipped to the US." }, status: :bad_request if card[:card_type] == "physical" && card[:shipping_address_country] != "US"

        @stripe_card = ::StripeCardService::Create.new(
          current_user:,
          ip_address: request.remote_ip,
          event_id: event.id,
          card_type: card[:card_type],
          stripe_shipping_name: card[:shipping_name],
          stripe_shipping_address_city: card[:shipping_address_city],
          stripe_shipping_address_state: card[:shipping_address_state],
          stripe_shipping_address_line1: card[:shipping_address_line1],
          stripe_shipping_address_line2: card[:shipping_address_line2],
          stripe_shipping_address_postal_code: card[:shipping_address_postal_code],
          stripe_shipping_address_country: card[:shipping_address_country],
          stripe_card_personalization_design_id: card[:card_personalization_design_id] || StripeCard::PersonalizationDesign.default&.id
        ).run

        return render json: { error: "internal_server_error" }, status: :internal_server_error if @stripe_card.nil?

        render :show, status: :created, location: api_v4_stripe_card_path(@stripe_card)
      end

      def update # deprecated: use freeze, defrost, and activate instead
        if params[:status] == "frozen"
          freeze
        elsif params[:status] == "active"
          stripe_card = StripeCard.find_by_public_id!(params[:id])
          if stripe_card.initially_activated?
            defrost
          else
            activate
          end
        else
          skip_authorization
          render json: { error: "Invalid status" }, status: :unprocessable_entity
        end
      end

      def cancel
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        if @stripe_card.canceled?
          return render json: { error: "Card is already cancelled" }, status: :unprocessable_entity
        end

        begin
          @stripe_card.cancel!
          render json: { success: "Card cancelled successfully" }
        rescue => e
          render json: { error: "Failed to cancel card", message: e.message }, status: :internal_server_error
        end
      end

      def ephemeral_keys
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        return render json: { error: "not_authorized" }, status: :forbidden unless current_token.application&.trusted?
        return render json: { error: "invalid_operation", messages: ["card must be virtual"] }, status: :bad_request unless @stripe_card.virtual?

        @ephemeral_key = @stripe_card.ephemeral_key(nonce: params[:nonce], stripe_version: params[:stripe_version] || "2020-03-02")

        ahoy.track "Card details shown", stripe_card_id: @stripe_card.id, user_id: current_user.id, oauth_token_id: current_token.id

        render json: { ephemeralKeyId: @ephemeral_key.id, ephemeralKeySecret: @ephemeral_key.secret, ephemeralKeyCreated: @ephemeral_key.created, ephemeralKeyExpires: @ephemeral_key.expires, stripe_id: @stripe_card.stripe_id }
      end

      def card_designs
        if params[:event_id].present?
          set_api_event
          authorize @event, :create_stripe_card?, policy_class: EventPolicy

          @designs = [@event.stripe_card_personalization_designs&.available, StripeCard::PersonalizationDesign.common.available].flatten.compact
        else
          skip_authorization
          @designs = StripeCard::PersonalizationDesign.common.available
        end

        @designs += StripeCard::PersonalizationDesign.unlisted.available if current_user.auditor?
      end

      def freeze
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        if @stripe_card.canceled?
          return render json: { error: "Card is canceled." }, status: :unprocessable_entity
        end

        @stripe_card.freeze!(frozen_by: current_user)
        return render json: { success: "Card frozen!" }
      end

      def defrost
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        if @stripe_card.stripe_status == "active"
          return render json: { error: "Card is already active." }, status: :unprocessable_entity
        end

        @stripe_card.defrost!
        return render json: { success: "Card defrosted!" }
      end

      def activate
        @stripe_card = authorize StripeCard.find_by_public_id!(params[:id])

        if params[:last4].blank?
          return render json: { error: "Last four digits are required." }, status: :unprocessable_entity
        end

        # Find the correct card based on it's last4
        card = current_user.stripe_cardholder&.stripe_cards&.find_by(last4: params[:last4])
        if card.nil? || card.id != @stripe_card.id
          return render json: { error: "Last four digits are incorrect." }, status: :unprocessable_entity
        end

        if @stripe_card.canceled?
          return render json: { error: "Card is canceled." }, status: :unprocessable_entity
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
  end
end
