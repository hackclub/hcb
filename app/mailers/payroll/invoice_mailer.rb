# frozen_string_literal: true

module Payroll
  class InvoiceMailer < ApplicationMailer
    def submitted
      @invoice = params[:invoice]
      @position = @invoice.payroll_position
      @event = @position.event

      managers = @event.managers.map(&:email_address_with_name)
      return if managers.empty?

      mail(
        to: managers,
        subject: "#{@position.display_name} submitted an invoice for #{@invoice.amount.format}",
        from: hcb_email_with_name_of(@event)
      )
    end

  end
end
