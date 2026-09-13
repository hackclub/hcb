# frozen_string_literal: true

module Api
  module V5
    class StripeCardsController < ApplicationController
      include Api::V5::TransferCreation
      include Api::V5::ScopedResource

      scoped_resource StripeCard, organization_scope: :event,
                                  preload: [:event, :user, :stripe_cardholder]

      require_oauth2_scope "cards:read", :index, :show

      def create
        event = find_organization!(params.require(:card)[:organization_id])
        authorize event, :create_stripe_card?, policy_class: EventPolicy

        attrs = permitted_attributes(StripeCard.new(event:))

        if (message = card_issuance_blocker(attrs))
          return render json: { error: "invalid_operation", messages: [message] }, status: :bad_request
        end

        @record = ::StripeCardService::Create.new(
          current_user:,
          ip_address: request.remote_ip,
          event_id: event.id,
          card_type: attrs[:card_type],
          stripe_shipping_name: attrs[:shipping_name],
          stripe_shipping_address_city: attrs[:shipping_address_city],
          stripe_shipping_address_state: attrs[:shipping_address_state],
          stripe_shipping_address_line1: attrs[:shipping_address_line1],
          stripe_shipping_address_line2: attrs[:shipping_address_line2],
          stripe_shipping_address_postal_code: attrs[:shipping_address_postal_code],
          stripe_shipping_address_country: attrs[:shipping_address_country],
          stripe_card_personalization_design_id: attrs[:card_personalization_design_id] || StripeCard::PersonalizationDesign.default&.id
        ).run

        return render json: { error: "internal_error" }, status: :internal_server_error if @record.nil?

        render :show, status: :created
      end

      require_oauth2_scope "cards:write", :create

      def freeze
        card = authorize find_card!

        return render json: { error: "invalid_operation", messages: ["Card is canceled."] }, status: :unprocessable_content if card.canceled?

        card.freeze!(frozen_by: current_user)
        render json: { message: "Card frozen" }
      end

      require_oauth2_scope "cards:write", :freeze

      def defrost
        card = authorize find_card!

        return render json: { error: "invalid_operation", messages: ["Card is already active."] }, status: :unprocessable_content if card.stripe_status == "active"

        card.defrost!
        render json: { message: "Card defrosted" }
      end

      require_oauth2_scope "cards:write", :defrost

      def cancel
        card = authorize find_card!

        return render json: { error: "invalid_operation", messages: ["Card is already canceled."] }, status: :unprocessable_content if card.canceled?

        card.cancel!
        render json: { message: "Card canceled" }
      end

      require_oauth2_scope "cards:write", :cancel

      private

      def find_card!
        StripeCard.find_by_public_id!(params[:id])
      end

      # Issuing a card needs a few things of the cardholder that the card
      # parameters cannot supply.
      def card_issuance_blocker(attrs)
        return "Birthday must be set before creating a card." if current_user.birthday.nil?
        return "Cards can only be shipped to the US." if attrs[:card_type] == "physical" && attrs[:shipping_address_country] != "US"
        return "A verified phone number is required to issue a card." unless current_user.phone_number_verified_or_bypassed?

        nil
      end
    end
  end
end
