# frozen_string_literal: true

# == Schema Information
#
# Table name: event_group_memberships
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_group_id :bigint           not null
#  event_id       :bigint           not null
#
# Foreign Keys
#
#  fk_rails_...  (event_group_id => event_groups.id)
#  fk_rails_...  (event_id => events.id)
#
class Event
  class GroupMembership < ApplicationRecord
    belongs_to(
      :group,
      class_name: "Event::Group",
      foreign_key: :event_group_id,
      inverse_of: :memberships
    )
    belongs_to(:event)

  end

end
