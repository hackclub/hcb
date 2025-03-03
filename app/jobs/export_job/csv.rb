# frozen_string_literal: true

module ExportJob
  class Csv < ApplicationJob
    queue_as :default
    def perform(event_id:, email:, public_only: false, start_date: nil, end_date: nil)
      @event = Event.find(event_id)

      datetime = Time.now.to_formatted_s(:db)
      title = "transaction_export_#{@event.name}_#{datetime}"
              .gsub(/[^0-9a-z_]/i, "-").gsub(" ", "_")
      title += ".csv"

      csv_enumerator = ExportService::Csv.new(event_id:, public_only:, start_date:, end_date:).run
      csv = csv_enumerator.reduce(:+)

      ExportMailer.export_ready(
        event: @event,
        email:,
        mime_type: "text/csv",
        title:,
        content: csv
      ).deliver_later
    end

  end
end
