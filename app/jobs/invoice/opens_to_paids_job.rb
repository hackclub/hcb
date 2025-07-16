# frozen_string_literal: true

class Invoice
  class OpensToPaidsJob < ApplicationJob
    queue_as :low
    def perform
      ::InvoiceService::OpensToPaids.new.run
    end

  end

end
