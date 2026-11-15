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

      mail(
        to: contractor_recipients,
        subject: "Your #{@invoice.amount.format} invoice to #{@event.name} was rejected",
        from: hcb_email_with_name_of(@event),
        reply_to: reviewer_addresses
      )
    end

    private

    def contractor_recipients
      payee = @position.payee
      users = payee.legal_entity&.users

      users.present? ? users.map(&:email_address_with_name) : [payee.email]
    end

    # Replies go to whoever can explain the decision, not to HCB.
    def reviewer_addresses
      reviewers = [@invoice.reviewed_by, @position.manager].compact.uniq
      return reviewers.map(&:email_address_with_name) if reviewers.any?

      @event.organizer_contact_emails(only_managers: true)
    end

  end
end
