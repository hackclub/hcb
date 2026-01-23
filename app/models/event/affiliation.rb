# frozen_string_literal: true

# == Schema Information
#
# Table name: event_affiliations
#
#  id              :bigint           not null, primary key
#  affiliable_type :string           not null
#  metadata        :jsonb            not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  affiliable_id   :bigint           not null
#  event_id        :bigint           not null
#
# Indexes
#
#  index_event_affiliations_on_affiliable  (affiliable_type,affiliable_id)
#  index_event_affiliations_on_event_id    (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Event
  class Affiliation < ApplicationRecord
    include Hashid::Rails

    belongs_to :event
    belongs_to :affiliable, polymorphic: true

    store_accessor :metadata, :league, :team_number, :size, :venue_name

    scope :robotics, -> { where(name: %w[first vex]) }

    def display_name
      case name
      when "first"
        "FIRST"
      when "vex"
        "VEX"
      when "hack_club"
        "Hack Club"
      end
    end

    def is_first?
      name == "first"
    end

    def is_vex?
      name == "vex"
    end

    def is_hack_club?
      name == "hack_club"
    end

  end

end
