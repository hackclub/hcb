# frozen_string_literal: true

class AnnouncementMailerPreview < ActionMailer::Preview
  def announcement_published
    @announcement = Announcement.last
    AnnouncementMailer.with(announcement: @announcement, email: "admin@bank.engineering").announcement_published
  end

  def monthly_warning
    AnnouncementMailer.with(event: Event.transparent.last).monthly_warning
  end

end
