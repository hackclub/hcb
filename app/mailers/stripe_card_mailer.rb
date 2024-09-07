# frozen_string_literal: true

class StripeCardMailer < ApplicationMailer
  before_action :set_shared_variables, except: [:design_rejected]

  def physical_card_ordered
    @has_multiple_events = @user.events.size > 1
    @eta = params[:eta] || @card.stripe_obj.to_hash[:shipping][:eta]

    mail to: @recipient,
         subject: "Your new HCB card for #{@event.name} is on its way"
  end

  def lost_in_shipping
    mail to: @recipient,
         subject: "Your HCB card for #{@event.name} was lost in shipping."
  end

  def virtual_card_ordered
    mail to: @recipient,
         subject: "New virtual HCB card (ending in #{@card.last4}) for #{@event.name}"
  end

  def design_rejected
    @event = params[:event]
    @reason = humanize_design_rejected_reason(params[:reason])

    return unless @event

    mail to: @event.users.map(&:email_address_with_name), subject: "Your card logo was rejected by our card issuer"
  end

  private

  def set_shared_variables
    @card = StripeCard.find(params[:card_id])
    @user = @card.user
    @event = @card.event
    @recipient = @user.email_address_with_name
  end

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
