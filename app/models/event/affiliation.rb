# frozen_string_literal: true

# == Schema Information
#
# Table name: event_affiliations
#
#  id         :bigint           not null, primary key
#  metadata   :jsonb            not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
#
# Indexes
#
#  index_event_affiliations_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Event
  class Affiliation < ApplicationRecord
    belongs_to :event

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

    def league
      metadata["league"] if is_first? || is_vex?
    end

    def team_number
      metadata["team_number"] if is_first? || is_vex?
    end

    def size
      metadata["size"] if is_first? || is_vex? || is_hack_club?
    end

    def venue_name
      metadata["venue_name"] if is_hack_club?
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
