# frozen_string_literal: true

module Payroll
  class InvoiceMailerPreview < ActionMailer::Preview
    def submitted
      Payroll::InvoiceMailer.with(invoice: Payroll::Invoice.last).submitted
    end

    def rejected
      Payroll::InvoiceMailer.with(invoice: Payroll::Invoice.rejected.last).rejected
    end

  end
end
