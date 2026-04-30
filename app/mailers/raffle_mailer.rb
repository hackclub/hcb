# frozen_string_literal: true

class RaffleMailer < ApplicationMailer
  def extra_ticket_earned
    @raffle = params[:raffle]
    @user = @raffle.user

    mail to: @user.email_address_with_name, subject: "You've earned an extra raffle ticket!"
  end
end
