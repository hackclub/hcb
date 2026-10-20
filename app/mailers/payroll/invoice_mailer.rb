# frozen_string_literal: true

module Payroll
  class InvoiceMailer < ApplicationMailer
    include IndividualDelivery

    def submitted
      @invoice = params[:invoice]
      @position = @invoice.payroll_position
      @event = @position.event

      recipients = Array(@position.manager&.email_address_with_name || @event.organizer_contact_emails(only_managers: true))

      mail_individually(
        recipients,
        subject: "#{@position.payee.display_name} submitted an invoice for #{@invoice.amount.format}",
        from: hcb_email_with_name_of(@event)
      )
    end

  end
end
