# frozen_string_literal: true

# == Schema Information
#
# Table name: event_scoped_tags
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  parent_event_id :bigint           not null
#
# Indexes
#
#  index_event_scoped_tags_on_parent_event_id  (parent_event_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_event_id => events.id)
#
class Event
  class ScopedTag < ApplicationRecord
    include ActionView::Helpers::TextHelper # for `pluralize`

    has_many :event_scoped_tags_events, foreign_key: :event_scoped_tag_id, inverse_of: :event_scoped_tag, class_name: "Event::ScopedTagsEvent", dependent: :destroy
    has_many :events, through: :event_scoped_tags_events

    belongs_to :parent_event, class_name: "Event"

    validate :name_is_unique_within_parent_event

    def removal_confirmation_message
      message = "Are you sure you'd like to delete this tag?"

      if events.length > 0
        message + " It will be removed from #{pluralize(events.length, 'event')}."
      else
        message
      end
    end

    private

    def name_is_unique_within_parent_event
      if parent_event.subevent_scoped_tags.where(name:).exists?
        errors.add(:name, "is not unique within the parent event")
      end
    end

  end

end
