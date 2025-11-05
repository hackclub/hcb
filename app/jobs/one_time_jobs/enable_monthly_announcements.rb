# frozen_string_literal: true

module OneTimeJobs
  class EnableMonthlyAnnouncements < ApplicationJob
    def perform(exclude_ids:)
      eligible_events = Event.transparent.organized_by_teenagers.where.not(id: exclude_ids).includes(:config).where(config: { generate_monthly_announcement: false }, id: OrganizerPosition.pluck(:event_id))

      eligible_events.each do |event|
        event.config.update!(generate_monthly_announcement: true)

        # A callback on Event::Configuration will automatically create a new monthly announcement when the column is updated
        monthly_announcement = event.announcements.monthly.last

        AnnouncementMailer.with(event:, monthly_announcement:).notice.deliver_later
      end
    end

  end

end
