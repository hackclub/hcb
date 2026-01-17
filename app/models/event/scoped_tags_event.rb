# frozen_string_literal: true

# == Schema Information
#
# Table name: event_scoped_tags_events
#
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  event_id            :bigint           not null, primary key
#  event_scoped_tag_id :bigint           not null, primary key
#
# Indexes
#
#  idx_on_event_scoped_tag_id_event_id_4b716d1ac0         (event_scoped_tag_id,event_id) UNIQUE
#  index_event_scoped_tags_events_on_event_id             (event_id)
#  index_event_scoped_tags_events_on_event_scoped_tag_id  (event_scoped_tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (event_scoped_tag_id => event_scoped_tags.id)
#
class Event
  class ScopedTagsEvent < ApplicationRecord
    self.primary_key = [:event_id, :event_scoped_tag_id]

    after_create_commit { broadcast_render_later_to([event_scoped_tag.parent_event, :scoped_tags], partial: "events/scoped_tags/create", locals: { subevent: event, scoped_tag: event_scoped_tag, streamed: true }) }
    after_destroy_commit { broadcast_render_to([event_scoped_tag.parent_event, :scoped_tags], partial: "events/scoped_tags/destroy", locals: { subevent: event, scoped_tag: event_scoped_tag, streamed: true }) }

    belongs_to :event
    belongs_to :event_scoped_tag, class_name: "Event::ScopedTag"

    validate :event_is_subevent

    private

    def event_is_subevent
      if event.parent_id.nil?
        errors.add(:event, "must be a subevent to be tagged with a scoped tag")
      end
    end

  end

end
