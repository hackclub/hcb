# frozen_string_literal: true

# == Schema Information
#
# Table name: event_configurations
#
#  id                  :bigint           not null, primary key
#  anonymous_donations :boolean          default(FALSE)
#  cover_donation_fees :boolean          default(FALSE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  event_id            :bigint           not null
#
# Indexes
#
#  index_event_configurations_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Event
  class Configuration < ApplicationRecord
    belongs_to :event

  end

end
