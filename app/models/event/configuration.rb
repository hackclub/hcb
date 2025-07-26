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
#  index_event_configurations_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Event
  class Configuration < ApplicationRecord
    belongs_to :event
    validates_email_format_of :contact_email, allow_nil: true, allow_blank: true
    normalizes :contact_email, with: ->(contact_email) { contact_email.strip.downcase }
    validates :subevent_plan, inclusion: { in: -> { Event::Plan.available_plans.map(&:name) } }, allow_blank: true

    after_create :set_defaults

    private

    def set_defaults
      self.generate_monthly_announcement = event.is_public unless self.generate_monthly_announcement.present?
    end

  end

end
