# frozen_string_literal: true

class CardGrantMailer < ApplicationMailer
  def card_grant_notification
    @card_grant = params[:card_grant]
    @custom_invite_message = @card_grant.setting.invite_message

    mail to: @card_grant.user.email_address_with_name, subject: "[#{@card_grant.event.name}] You've received a #{@card_grant.amount.format} grant!"
  end

end
