# frozen_string_literal: true

module Payroll
  class InvoiceMailer < ApplicationMailer
    def submitted
      @invoice = params[:invoice]
      @position = @invoice.payroll_position
      @event = @position.event

      email_recipients = @position.manager&.email_address_with_name || @event.organizer_contact_emails(only_managers: true)

      mail(
        to: email_recipients,
        subject: "#{@position.payee.display_name} submitted an invoice for #{@invoice.amount.format}",
        from: hcb_email_with_name_of(@event)
      )
    end

    def rejected
      @invoice = params[:invoice]
      @position = @invoice.payroll_position
      @event = @position.event
      payee = @position.payee

      mail(
        to: payee.legal_entity&.users&.map(&:email_address_with_name).presence || payee.email,
        subject: "#{@event.name} rejected your invoice for #{@invoice.amount.format}",
        from: hcb_email_with_name_of(@event),
        reply_to: @invoice.reviewed_by&.email_address_with_name
      )
    end

  end
end
