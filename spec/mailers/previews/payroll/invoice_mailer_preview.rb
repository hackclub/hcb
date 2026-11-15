# frozen_string_literal: true

module Payroll
  class InvoiceMailerPreview < ActionMailer::Preview
    def rejected
      invoice = Payroll::Invoice.rejected.last

      Payroll::InvoiceMailer.with(invoice:).rejected
    end

  end
end
