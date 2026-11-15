# frozen_string_literal: true

module Payroll
  class InvoiceMailerPreview < ActionMailer::Preview
    def submitted
      Payroll::InvoiceMailer.with(invoice: Payroll::Invoice.last).submitted
    end

    def rejected
      invoice = Payroll::Invoice.rejected.where.not(rejection_reason: nil).last || Payroll::Invoice.last
      invoice.rejection_reason ||= "The hours on this invoice don't match the timesheet.\nPlease resubmit with the corrected total."

      Payroll::InvoiceMailer.with(invoice:).rejected
    end

  end
end
