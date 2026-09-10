# frozen_string_literal: true

module Maintenance
  # Fills Event#description (the "Mission statement" settings field) from the
  # Airtable record's "Tell us about your event" field for events created
  # without an application. The application-description backfill ships inline
  # in the deploy migration; this task covers the application-less events that
  # came from Airtable. Safe to re-run; only fills blank descriptions.
  class BackfillEventDescriptionsTask < MaintenanceTasks::Task
    def collection
      # Event.default_scope adds ORDER BY id, which job-iteration's
      # ActiveRecordCursor does not support. Strip the ordering while keeping
      # the paranoid deleted_at filter.
      Event.unscope(:order).where(description: [nil, ""]).where.missing(:application)
    end

    def process(event)
      airtable_desc = event.airtable_record&.[]("Tell us about your event")
      event.update_column(:description, airtable_desc) if airtable_desc.present?
    rescue Airrecord::Error => e
      # Airtable is unreachable (e.g. unconfigured in dev/test) — report and
      # move on rather than aborting the run.
      Rails.error.report(e)
    end

  end
end
