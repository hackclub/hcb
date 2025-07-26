# frozen_string_literal: true

class Event
  class SyncToAirtableSingleJob < ApplicationJob
    queue_as :low

    def perform(event)
      event.sync_to_airtable
    end

  end

end
