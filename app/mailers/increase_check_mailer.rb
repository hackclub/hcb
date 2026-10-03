# frozen_string_literal: true

class IncreaseCheckMailer < ApplicationMailer
  def notify_recipient
    @check = params[:check]

    mail to: @check.recipient_email,
         subject: "Your check (##{@check.check_number}) from #{@check.event.name} is in transit",
         from: email_address_with_name("hcb@hackclub.com", "#{@check.event.name} via HCB"),
         reply_to: @check.event.organizer_positions.where(role: :manager).includes(:user).map { |op| op.user.email_address_with_name }
  end

  def notify_stopped
    @check = params[:check]

    mail to: @check.recipient_email,
         subject: "Your check (##{@check.check_number}) from #{@check.event.name} has been stopped",
         from: email_address_with_name("hcb@hackclub.com", "#{@check.event.name} via HCB"),
         reply_to: @check.event.organizer_positions.where(role: :manager).includes(:user).map { |op| op.user.email_address_with_name }
  end

  def remind_recipient
    @check = params[:check]

    mail to: @check.recipient_email,
         subject: "[Action Required] You haven't deposited your check (##{@check.check_number}) from #{@check.event.name}",
         from: email_address_with_name("hcb@hackclub.com", "#{@check.event.name} via HCB"),
         reply_to: @check.event.organizer_positions.where(role: :manager).includes(:user).map { |op| op.user.email_address_with_name }
  end

end
