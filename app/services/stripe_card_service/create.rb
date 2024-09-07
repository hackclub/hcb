# frozen_string_literal: true

module StripeCardService
  class Create
    def initialize(current_user:, current_session:, event_id:,
                   card_type:, subledger: nil,
                   stripe_shipping_name: nil, stripe_shipping_address_city: nil,
                   stripe_shipping_address_state: nil, stripe_shipping_address_line1: nil,
                   stripe_shipping_address_line2: nil, stripe_shipping_address_postal_code: nil,
                   stripe_shipping_address_country: "US", stripe_card_personalization_design_id: nil)
      @current_user = current_user
      @current_session = current_session
      @event_id = event_id
      @subledger = subledger

      @card_type = card_type
      @stripe_shipping_name = stripe_shipping_name
      @stripe_shipping_address_city = stripe_shipping_address_city
      @stripe_shipping_address_state = stripe_shipping_address_state
      @stripe_shipping_address_line1 = stripe_shipping_address_line1
      @stripe_shipping_address_line2 = stripe_shipping_address_line2
      @stripe_shipping_address_postal_code = stripe_shipping_address_postal_code
      @stripe_shipping_address_country = stripe_shipping_address_country
      @stripe_card_personalization_design_id = stripe_card_personalization_design_id
      @stripe_personalization_design_id = @stripe_card_personalization_design_id ? StripeCard::PersonalizationDesign.find(@stripe_card_personalization_design_id).stripe_id : nil
    end

    def run
      raise ArgumentError, "not permitted under spend only plan" if event.unapproved?

      stripe_cardholder

      ActiveRecord::Base.transaction do
        card = event.stripe_cards.create!(attrs)

        remote_stripe_card = create_remote_stripe_card!

        card.stripe_id = remote_stripe_card.id # necessary because of design of sync_from_stripe
        card.sync_from_stripe!
        card.save!

        card
      end
    end

    private

    def attrs
      attrs = {
        card_type: @card_type,
        subledger: @subledger,
        stripe_cardholder_id: stripe_cardholder.id,
        stripe_shipping_name: @stripe_shipping_name,
        stripe_shipping_address_city: @stripe_shipping_address_city,
        stripe_shipping_address_state: @stripe_shipping_address_state,
        stripe_shipping_address_country: @stripe_shipping_address_country,
        stripe_shipping_address_line1: @stripe_shipping_address_line1,
        stripe_shipping_address_line2: formatted_stripe_shipping_address_line2,
        stripe_shipping_address_postal_code: @stripe_shipping_address_postal_code
      }.compact

      attrs[:stripe_card_personalization_design_id] = @stripe_card_personalization_design_id if physical?

      attrs
    end

    def formatted_stripe_shipping_address_line2
      @stripe_shipping_address_line2.present? ? @stripe_shipping_address_line2 : nil
    end

    def create_remote_stripe_card!
      ::StripeService::Issuing::Card.create(remote_card_attrs)
    end

    def remote_card_attrs
      attrs = {
        cardholder: stripe_cardholder.stripe_id,
        type: @card_type,
        second_line: event.short_name(length: 24),
        currency: "usd",
        status: "active",
        spending_controls: {
          spending_limits: [
            {
              interval: "daily",
              amount: 20_000 * 100 # $20,000 in cents
            }
          ]
        }
      }
      if physical?
        attrs[:status] = "inactive"
        attrs[:shipping] = {
          name: @stripe_shipping_name,
          service: shipping_type,
          address: {
            line1: @stripe_shipping_address_line1,
            line2: formatted_stripe_shipping_address_line2,
            city: @stripe_shipping_address_city,
            state: @stripe_shipping_address_state,
            country: @stripe_shipping_address_country,
            postal_code: @stripe_shipping_address_postal_code
          }.compact
        }.compact
        attrs[:personalization_design] = @stripe_personalization_design_id if @stripe_personalization_design_id
      end

      attrs
    end

    def shipping_type
      @shipping_type ||= event.stripe_card_shipping_type
    end

    def stripe_cardholder
      @stripe_cardholder ||= ::StripeCardholder.find_by(user: @current_user) || ::StripeCardholderService::Create.new(**cardholder_attrs).run
    end

    def cardholder_attrs
      {
        current_user: @current_user,
        current_session: @current_session,
        event_id: event.id
      }
    end

    def event
      @event ||= Event.find(@event_id)
    end

    def virtual?
      @card_type == "virtual" || @card_type == 0 || @card_type == "0"
    end

    def physical?
      !virtual?
    end

  end
end
