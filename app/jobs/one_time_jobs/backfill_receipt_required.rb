# frozen_string_literal: true

module OneTimeJobs
  class BackfillReceiptRequired < ApplicationJob
    queue_as :metrics

    def perform(event_id: nil)
      ledger_items = event_id.nil? ? Ledger::Item.all : Event.find(event_id).ledger_items

      ledger_items.find_each do |item|
        item.update!(receipt_required: item.calculate_receipt_required)
      end
    end

  end
end
