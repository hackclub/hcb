# frozen_string_literal: true

# == Schema Information
#
# Table name: event_configurations
#
#  id                            :bigint           not null, primary key
#  anonymous_donations           :boolean          default(FALSE)
#  contact_email                 :string
#  cover_donation_fees           :boolean          default(FALSE)
#  generate_monthly_announcement :boolean          default(FALSE), not null
#  subevent_plan                 :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  event_id                      :bigint           not null
#
# Indexes
#
#  index_event_configurations_on_event_id  (event_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Event
  class Configuration < ApplicationRecord
    has_paper_trail

    belongs_to :event
    validates_email_format_of :contact_email, allow_nil: true, allow_blank: true
    normalizes :contact_email, with: ->(contact_email) { contact_email.strip.downcase }
    validates :subevent_plan, inclusion: { in: -> { Event::Plan.available_plans.map(&:name) } }, allow_blank: true
    validates :event, uniqueness: true

    after_save :create_or_destroy_monthly_announcement
    after_update if: :generate_monthly_announcement_previously_changed? do
      whodunnit = User.find(self.versions.where_object_changes(generate_monthly_announcement:).last.whodunnit)
      if generate_monthly_announcement
        EventMailer.with(event:, whodunnit:).monthly_announcements_enabled.deliver_later
      else
        EventMailer.with(event:, whodunnit:).monthly_announcements_disabled.deliver_later
      end
    end

    private

    def create_or_destroy_monthly_announcement
      if self.generate_monthly_announcement_previously_changed?
        if self.generate_monthly_announcement
          Announcement::Templates::Monthly.new(event: self.event, author: User.system_user).create if self.event.announcements.all_monthly_for(Date.today).empty?
        else
          monthly_announcement_draft = self.event.announcements.all_monthly_for(Date.today).first
          monthly_announcement_draft&.destroy! unless monthly_announcement_draft&.published?
        end
      end
    end

  end

end
