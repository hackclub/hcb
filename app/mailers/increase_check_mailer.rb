# frozen_string_literal: true

class IncreaseCheckMailer < ApplicationMailer
  def notify_recipient
    @check = params[:check]

    mail to: @check.recipient_email,
         subject: "Your check (##{@check.check_number}) from #{@check.event.name} is in transit",
         from: hcb_email_with_name_of(@check.event),
         reply_to: @check.event.organizer_contact_emails(only_managers: true, include_contact_email: false)
  end

  def notify_stopped
    @check = params[:check]

    mail to: @check.recipient_email,
         subject: "Your check (##{@check.check_number}) from #{@check.event.name} has been stopped",
         from: hcb_email_with_name_of(@check.event),
         reply_to: @check.event.organizer_contact_emails(only_managers: true, include_contact_email: false)
  end

  def remind_recipient
    @check = params[:check]

    mail to: @check.recipient_email,
         subject: "[Action Required] You haven't deposited your check (##{@check.check_number}) from #{@check.event.name}",
         from: hcb_email_with_name_of(@check.event),
         reply_to: @check.event.organizer_contact_emails(only_managers: true, include_contact_email: false)
  end

end
