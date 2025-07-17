# frozen_string_literal: true

class Announcement
  class MonthlyJob < ApplicationJob
    queue_as :default
    def perform
      Announcement.monthly.where("announcements.created_at >= ?", Date.today.prev_month.beginning_of_month).find_each do |announcement|
        Rails.error.handle do
          announcement.publish!
        end
      end

      Event.transparent.each do |event|
        announcement = Announcement::Templates::Monthly.new(event:, author: event.signees.first).create
        announcement.create
      end
    end

  end

end
