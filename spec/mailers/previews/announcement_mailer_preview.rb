# frozen_string_literal: true

class AnnouncementMailerPreview < ActionMailer::Preview
  def announcement_published
    @announcement = Announcement.last
    AnnouncementMailer.with(announcement: @announcement, email: "admin@bank.engineering").announcement_published
  end

end
