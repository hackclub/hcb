# frozen_string_literal: true

module OneTimeJobs
  class BackfillLinkedObject < ApplicationJob
    queue_as :metrics

    def perform(event_id: nil)
      event = Event.find(event_id)
      ledger_items = event.ledger_items

      ledger_items.find_each do |item|
        item.update!(linked_object: item.hcb_code.linked_object) unless item.hcb_code.linked_object.nil?
      end
    end

  end
end
