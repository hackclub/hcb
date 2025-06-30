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
    class Vex < Affiliation
      def name
        "VEX"
      end

      def questions
        {
          team_name: {
            label: "What is your team's name?",
            require: true,
            type: {
              input: :string
            }
          },
          team_number: {
            label: "What is your team's number?",
            require: true,
            type: {
              input: :string
            }
          },
          league: {
            label: "What is your VEX program?",
            require: true,
            type: {
              input: :select,
              options: ["123", "GO", "AIM", "IQ", "EXP", "V5", "CTE", "AIR", "AIM", "PRO"]
            }
          }
        }
      end

    end

  end

end
