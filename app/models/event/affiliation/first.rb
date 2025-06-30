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
    class First < Affiliation
      def name
        "FIRST"
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
              input: :number
            }
          },
          league: {
            label: "What is your FIRST program?",
            require: true,
            type: {
              input: :select,
              options: ["FRC", "FTC", "FLL"]
            }
          },
          team_type: {
            label: "What is your team's type?",
            require: true,
            type: {
              input: :select,
              options: ["School", "Family/Community"]
            }
          },
          school_name: {
            label: "What is your school/community's name?",
            require: true,
            type: {
              input: :string
            }
          }
        }
      end

    end

  end

end
