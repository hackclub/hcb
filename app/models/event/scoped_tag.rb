# frozen_string_literal: true

# == Schema Information
#
# Table name: event_scoped_tags
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Event
  class ScopedTag < ApplicationRecord
    has_and_belongs_to_many :events, foreign_key: :event_scoped_tag_id, inverse_of: :scoped_tags

  end

end
