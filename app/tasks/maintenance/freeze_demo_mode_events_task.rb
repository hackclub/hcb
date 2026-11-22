# frozen_string_literal: true

module Maintenance
  # One-time backfill: financially freeze existing demo organizations before
  # removing demo mode checks. Run once after deploying, before deploying that removal.
  class FreezeDemoModeEventsTask < MaintenanceTasks::Task
    def collection
      Event.with_deleted.where(demo_mode: true, financially_frozen: false)
    end

    def process(event)
      # Deleted organizations reject model saves but must stay frozen if restored.
      Event.with_deleted.where(id: event.id).update_all(financially_frozen: true)
    end

  end
end
