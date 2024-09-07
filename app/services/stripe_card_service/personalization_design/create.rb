# frozen_string_literal: true

module StripeCardService
  module PersonalizationDesign
    class Create
      def initialize(file:, color: :black, event: nil, name: nil, common: false)
        @file = file
        @color = color
        @event = event
        @name = name
        @common = common
        raise ArgumentError unless StripeService.physical_bundle_ids[@color]
      end

      def carrier_text
        {
          header_title: carrier_text_header_title,
          header_body: "Visit hack.af/activate to activate your new card#{" for #{@event.name}" if @event.present?} from any device",
          footer_title: "https://hack.af/activate",
          footer_body: "Visit hack.af/activate to activate from any device"
        }
      end

      def carrier_text_header_title
        text = "HCB card for #{@event&.name}"

        if @event.present? && text.length <= 30
          text
        else
          "Your new HCB card is here"
        end
      end

      def run
        file = StripeService::File.create({ purpose: "issuing_logo", file: @file })
        @file.rewind
        pd = nil
        ActiveRecord::Base.transaction do
          pd = StripeCard::PersonalizationDesign.create!(event: @event, common: @common)
          pd.logo.attach(io: @file, filename: "#{Time.now.to_i}.png")
          pd.stripe_id = Stripe::Issuing::PersonalizationDesign.create({
                                                                         name: "#{@event&.name || @name || "Shared"} #{@color.to_s.titleize} Card (#{pd.id})",
                                                                         physical_bundle: StripeService.physical_bundle_ids[@color],
                                                                         card_logo: file,
                                                                         carrier_text:
                                                                       }).id
          pd.save!
        end

        pd.sync_from_stripe!

        pd
      end

    end
  end
end
