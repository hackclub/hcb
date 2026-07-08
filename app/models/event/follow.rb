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
