# frozen_string_literal: true

# == Schema Information
#
# Table name: event_tags
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string           not null
#  purpose     :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class EventTag < ApplicationRecord
  include ActionView::Helpers::TextHelper # for `pluralize`

  has_and_belongs_to_many :events

  validates :name, presence: true, uniqueness: { scope: :purpose }

  def removal_confirmation_message
    message = "Are you sure you'd like to delete this tag?"
    return message if events.none?

    message + " It will be removed from #{pluralize(events.size, 'organization')}."
  end

  def api_name(format = :short)
    components = [name]
    components << purpose unless format == :short
    components.compact.join("_").parameterize.underscore
  end

  def full_name
    return name unless purpose.present?

    "#{purpose}: #{name}"
  end

  module Tags
    ORGANIZED_BY_HACK_CLUBBERS = "Organized by Hack Clubbers"
    ORGANIZED_BY_TEENAGERS = "Organized by Teenagers"
    CLIMATE = "Climate"
    PARTNER_128_COLLECTIVE_FUNDED = "128 Collective Funded"
    PARTNER_128_COLLECTIVE_RECOMMENDED = "128 Collective Recommended"
    VERMONT_BASED = "Vermont-based"
    ROBOTICS_TEAM = "Robotics Team"
    HACKATHON = "Hackathon"
    HACK_CLUB = "Hack Club"
  end

end
