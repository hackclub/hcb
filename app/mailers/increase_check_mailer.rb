# frozen_string_literal: true

class IncreaseCheckMailer < ApplicationMailer
  def notify_recipient
    @check = params[:check]

    mail to: @check.recipient_email,
         subject: "Your check from #{@check.event.name} is in transit",
         from: email_address_with_name("hcb@hackclub.com", "#{@check.event.name} via HCB"),
         reply_to: @check.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email_address_with_name)
  end

  def remind_recipient
    @check = params[:check]

    mail to: @check.recipient_email,
         subject: "[Action Required] You haven't deposited your check from #{@check.event.name}",
         from: email_address_with_name("hcb@hackclub.com", "#{@check.event.name} via HCB"),
         reply_to: @check.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email_address_with_name)
  end

end
