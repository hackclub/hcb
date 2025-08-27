# frozen_string_literal: true

# == Schema Information
#
# Table name: event_groups
#
#  id         :bigint           not null, primary key
#  name       :citext           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_event_groups_on_name     (name) UNIQUE
#  index_event_groups_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Event
  class Group < ApplicationRecord
    belongs_to(:user)
    has_many(
      :memberships,
      class_name: "Event::GroupMembership",
      inverse_of: :group
    )
    has_many(:events, through: :memberships)

    validates(:name, uniqueness: { case_sensitive: false }, presence: true)

  end

end
