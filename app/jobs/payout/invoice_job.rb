# frozen_string_literal: true

module Payout
  class InvoiceJob < ApplicationJob
    queue_as :default
    def perform(invoice_id)
      ::PayoutService::Invoice::Create.new(invoice_id:).run
    end

  end
end

module PayoutJob
  Invoice = Payout::InvoiceJob
end
