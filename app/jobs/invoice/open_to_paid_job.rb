# frozen_string_literal: true

class Invoice
  class OpenToPaidJob < ApplicationJob
    queue_as :low
    def perform(invoice_id)
      ::InvoiceService::OpenToPaid.new(invoice_id:).run
    end

  end

end

module InvoiceJob
  OpenToPaid = Invoice::OpenToPaidJob
end
