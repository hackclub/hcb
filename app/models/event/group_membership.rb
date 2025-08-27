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
# Indexes
#
#  index_event_group_memberships_on_event_group_id               (event_group_id)
#  index_event_group_memberships_on_event_id_and_event_group_id  (event_id,event_group_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (event_group_id => event_groups.id)
#  fk_rails_...  (event_id => events.id)
#
class Event
  class GroupMembership < ApplicationRecord
  end

end
