# frozen_string_literal: true

class StripeCardMailer < ApplicationMailer
  before_action :set_shared_variables

  def physical_card_ordered
    @has_multiple_events = @user.events.size > 1
    @eta = params[:eta] || @card.stripe_obj.to_hash[:shipping][:eta]

    mail to: @recipient,
         subject: "Your new HCB card for #{@event.name} is on its way"
  end

  def lost_in_shipping
    mail to: @recipient,
         subject: "Your HCB card (ending in #{@card.last4}) for #{@event.name} was lost in shipping."
  end

  def virtual_card_ordered
    mail to: @recipient,
         subject: "New virtual HCB card (ending in #{@card.last4}) for #{@event.name}"
  end

  private

  def set_shared_variables
    @card = StripeCard.find(params[:card_id])
    @user = @card.user
    @event = @card.event
    @recipient = @user.email
  end

end
