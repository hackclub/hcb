# frozen_string_literal: true

module InvoiceJob
  class Refund < ApplicationJob
    queue_as :default
    def perform(invoice, amount)
      return if invoice.refunded?

      if invoice.canonical_transactions.any?
        InvoiceService::Refund.new(invoice_id: invoice.id, amount:).run
      else
        InvoiceJob::Refund.set(wait: 1.day).perform_later(invoice, amount)
      end
    end

  end
end
