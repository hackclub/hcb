# frozen_string_literal: true

# == Schema Information
#
# Table name: event_affiliations
#
#  id         :bigint           not null, primary key
#  metadata   :jsonb
#  type       :string
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
  class Affiliation
    class HackClub < Affiliation
      def name
        "Hack Club"
      end

      def questions
        {
          club_name: {
            label: "What is your club's name?",
            require: true,
            type: {
              input: :string
            }
          },
          club_type: {
            label: "What is your club's type?",
            require: true,
            type: {
              input: :select,
              options: ["School", "Library", "Makerspace", "Virtual", "Other"]
            }
          }
        }
      end

    end

  end

end
