# frozen_string_literal: true

# == Schema Information
#
# Table name: event_follows
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_event_follows_on_event_id              (event_id)
#  index_event_follows_on_user_id_and_event_id  (user_id,event_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Event
  class Follow < ApplicationRecord
    include Hashid::Rails
    hashid_config salt: ""

    belongs_to :user
    belongs_to :event

    # TODO: validate :user uniqueness in scope :event_id

  end

end
