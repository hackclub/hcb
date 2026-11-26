# frozen_string_literal: true

module Payroll
  class InvoiceMailerPreview < ActionMailer::Preview
    def submitted
      Payroll::InvoiceMailer.with(invoice: Payroll::Invoice.last).submitted
    end

    def reviewed
      Payroll::InvoiceMailer.with(invoice: Payroll::Invoice.where.not(review_note: nil).last).reviewed
    end

  end
end
