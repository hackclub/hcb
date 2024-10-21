# frozen_string_literal: true

class StripeCard
  class PersonalizationDesignMailer < ApplicationMailer
    def design_rejected
      @event = params[:event]
      @reason = humanize_design_rejected_reason(params[:reason])

      return unless @event

      mail to: @event.users.map(&:email_address_with_name), subject: "Your card logo was rejected by our card issuer"
    end

    private

    def humanize_design_rejected_reason(reason)
      case reason
      when "malformatted_image"
        "The image needs to be no more than 512kb and no larger than 1000px by 200px."
      when "non_binary_image"
        "The image isn't in a binary format. Please convert it to black and white or use image manipulation software to threshold it."
      when "network_name"
        "The image or text incorrectly uses the name of a credit card network. Please remove or correct it."
      when "other_entity"
        "The image or text incorrectly uses the name of another entity. Please review and make necessary corrections."
      when "geographic_location"
        "The image or text includes the name of a geographic location. Please remove or alter it."
      when "non_fiat_currency"
        "The image or text references non-fiat currency. Please adjust it to comply with acceptable currency references."
      when "promotional_material"
        "The image or text contains advertising or promotional material. Please remove any promotional content."
      when "inappropriate"
        "The image or text contains inappropriate content. Please review and ensure the content is suitable."
      else
        "The image or text was flagged for another reason. Please contact us and we'll work with Stripe for you."
      end
    end

  end

end
