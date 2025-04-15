# frozen_string_literal: true

class Invoice
  class RefundJob < ApplicationJob
    queue_as :default
    def perform(invoice, amount, requested_by)
      return if invoice.refunded?

      if invoice.canonical_transactions.any?
        InvoiceService::Refund.new(invoice_id: invoice.id, amount:).run
        InvoiceMailer.with(invoice:, requested_by:).refunded.deliver_later if requested_by
      else
        Invoice::RefundJob.set(wait: 1.day).perform_later(invoice, amount, requested_by)
      end
    end

  end

end

module InvoiceJob
  Refund = Invoice::RefundJob
end
