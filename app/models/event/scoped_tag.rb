# frozen_string_literal: true

# == Schema Information
#
# Table name: event_scoped_tags
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Event
  class ScopedTag < ApplicationRecord
    has_many :event_scoped_tags_events, foreign_key: :event_scoped_tag_id, inverse_of: :event_scoped_tag, class_name: "Event::ScopedTagsEvent"
    has_many :events, through: :event_scoped_tags_events

  end

end
