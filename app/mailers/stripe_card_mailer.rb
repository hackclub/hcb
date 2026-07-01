# frozen_string_literal: true

class StripeCardMailer < ApplicationMailer
  before_action :set_shared_variables

  def physical_card_ordered
    @has_multiple_events = @user.events.size > 1
    @eta = @card.shipping_eta
    @delivery_reason = "you ordered a physical HCB card for #{@event.name}."

    mail to: @recipient,
         subject: "Your new HCB card for #{@event.name} is on its way"
  end

  def lost_in_shipping
    @delivery_reason = "you ordered a physical HCB card for #{@event.name}."

    mail to: @recipient,
         subject: "Your HCB card for #{@event.name} was lost in shipping."
  end

  def virtual_card_ordered
    @delivery_reason = "you ordered a virtual HCB card for #{@event.name}."
    
    mail to: @recipient,
         subject: "New virtual HCB card (ending in #{@card.last4}) for #{@event.name}"
  end

  private

  def set_shared_variables
    @card = StripeCard.find(params[:card_id])
    @user = @card.user
    @event = @card.event
    @recipient = @user.email_address_with_name
  end

end
