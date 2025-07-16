# frozen_string_literal: true

class Event
  class SyncToAirtableJob < ApplicationJob
    queue_as :low

    def perform
      # Get all applications that have an HCB ID. May return null so we compact.
      event_ids = ApplicationsTable.all(filter: '{HCB ID} != ""').pluck("HCB ID").compact

      Event.where(id: event_ids).find_each(batch_size: 100) do |event|
        SyncToAirtableSingleJob.perform_later(event)
      end
    end

  end

end
