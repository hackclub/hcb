# frozen_string_literal: true

class AnnouncementMailerPreview < ActionMailer::Preview
  def announcement_published
    @announcement = Announcement.last
    AnnouncementMailer.with(announcement: @announcement, email: "admin@bank.engineering").announcement_published
  end

  def seven_day_warning
    AnnouncementMailer.with(announcement: Announcement.monthly.last).seven_day_warning
  end

  def two_day_warning
    AnnouncementMailer.with(announcement: Announcement.monthly.last).two_day_warning
  end

  def notice
    AnnouncementMailer.with(event: Announcement.monthly.last.event, monthly_announcement: Announcement.monthly.last).notice
  end

  def skipped
    AnnouncementMailer.with(announcement: Announcement.monthly.last).skipped
  end

end
