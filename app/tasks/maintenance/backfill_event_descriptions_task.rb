# frozen_string_literal: true

module Maintenance
  # Fills Event#description (the "Mission statement" settings field) for
  # events created without one. Events with an application use the
  # application's description; application-less events fall back to the
  # Airtable record's "Tell us about your event" field. Safe to re-run; only
  # fills blank descriptions.
  class BackfillEventDescriptionsTask < MaintenanceTasks::Task
    def collection
      Event.unscope(:order).includes(:application).where(description: [nil, ""])
    end

    def process(event)
      description = event.application&.description.presence || event.airtable_record&.[]("Tell us about your event")

      event.update(description:) if description.present?
    rescue Airrecord::Error => e
      # Airtable is unreachable (e.g. unconfigured in dev/test) — report and
      # move on rather than aborting the run.
      Rails.error.report(e)
    end

  end
end
