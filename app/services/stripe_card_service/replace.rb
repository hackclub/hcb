# frozen_string_literal: true

module StripeCardService
  # https://docs.stripe.com/issuing/cards/replacements
  class Replace
    REASONS = %w[expired damaged lost stolen].freeze

    CANCEL_FIRST_REASONS = %w[lost stolen].freeze

    REQUIRED_SHIPPING_FIELDS = %i[name line1 city state postal_code].freeze

    class InvalidShippingAddressError < StandardError; end

    class OrderFailedError < StandardError; end

    def initialize(stripe_card:, reason:, ip_address:, shipping_address: nil)
      @stripe_card = stripe_card
      @reason = reason.to_s
      @ip_address = ip_address
      @shipping_address = (shipping_address || {}).to_h.symbolize_keys.transform_values { |value| value.to_s.strip.presence }
    end

    def run
      raise ArgumentError, "#{@reason.inspect} is not a supported replacement reason" unless REASONS.include?(@reason)
      raise ArgumentError, "a canceled card can't be replaced" if @stripe_card.canceled? && @reason != "expired"

      validate_shipping_address! if @stripe_card.physical?

      return order_replacement! unless CANCEL_FIRST_REASONS.include?(@reason)

      @stripe_card.cancel!(cancellation_reason: @reason)

      begin
        order_replacement!
      rescue => e
        raise OrderFailedError, "Card #{@stripe_card.id} was canceled as #{@reason}, but its replacement could not be ordered: #{e.message}"
      end
    end

    private

    def order_replacement!
      replacement = create_replacement!
      replacement.update(name: @stripe_card.name) if @stripe_card.name.present?
      activate!(replacement) if replacement.virtual?

      replacement
    end

    def create_replacement!
      StripeCardService::Create.new(
        current_user: @stripe_card.user,
        ip_address: @ip_address,
        event_id: @stripe_card.event_id,
        card_type: @stripe_card.card_type,
        replacement_for: @stripe_card,
        replacement_reason: @reason,
        **shipping_attrs
      ).run
    end

    def activate!(replacement)
      replacement.update!(initially_activated: true)
      replacement.defrost!

      return if @stripe_card.canceled?

      begin
        @stripe_card.cancel!
      rescue Stripe::InvalidRequestError
        @stripe_card.sync_from_stripe!
        @stripe_card.save!
      end
    end

    def validate_shipping_address!
      missing = REQUIRED_SHIPPING_FIELDS.select { |field| @shipping_address[field].blank? }
      if missing.any?
        raise InvalidShippingAddressError, "Shipping address is missing #{missing.map { |field| field.to_s.humanize(capitalize: false) }.to_sentence}."
      end

      unless ISO3166::Country["US"].subdivisions.key?(@shipping_address[:state].upcase)
        raise InvalidShippingAddressError, "#{@shipping_address[:state]} is not a US state."
      end
    end

    def shipping_attrs
      return {} unless @stripe_card.physical?

      {
        stripe_shipping_name: @shipping_address[:name],
        stripe_shipping_address_line1: @shipping_address[:line1],
        stripe_shipping_address_line2: @shipping_address[:line2],
        stripe_shipping_address_city: @shipping_address[:city],
        stripe_shipping_address_state: @shipping_address[:state].upcase,
        stripe_shipping_address_postal_code: @shipping_address[:postal_code],
        stripe_shipping_address_country: "US",
        stripe_card_personalization_design_id:,
      }
    end

    def stripe_card_personalization_design_id
      StripeCard::PersonalizationDesign.available.find_by(id: @stripe_card.stripe_card_personalization_design_id)&.id ||
        StripeCard::PersonalizationDesign.default&.id
    end

  end
end
