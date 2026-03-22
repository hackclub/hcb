# frozen_string_literal: true

class Announcement
  class PublishedJob < ApplicationJob
    queue_as :default
    def perform(announcement:)
      if announcement.published?
        announcement.event.followers.find_each do |follower|
          AnnouncementMailer.with(
            announcement:,
            email: follower.email_address_with_name
          ).announcement_published.deliver_later
        end
      end
    end

  end

end
