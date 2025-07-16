# frozen_string_literal: true

class Announcement
  class MonthlyJob < ApplicationJob
    queue_as :default
    def perform_later
      Announcement.monthly.where("announcements.created_at >= ?", Date.today.prev_month.beginning_of_month).each do |announcement|
        announcement.publish!
      end

      Event.transparent.each do |event|
        announcement = Announcement::Templates::Monthly.new(event:, author: event.signees.first).create
        announcement.create
      end
    end

  end

end
