# frozen_string_literal: true

# DEPRECATED

# This plan was used for high school hackathons from August 2022
# to December 2024 that had their HCB fees waived.

# See https://web.archive.org/web/20240918195546/https://hackclub.com/hackathons/grant/
# for additional context behind the .

# == Schema Information
#
# Table name: event_plans
#
#  id          :bigint           not null, primary key
#  aasm_state  :string
#  inactive_at :datetime
#  type        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  event_id    :bigint           not null
#
# Indexes
#
#  index_event_plans_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Event
  class Plan
    class HighSchoolHackathon < FeeWaived
      def label
        "high school hackathon (2024 fee waiver)"
      end

      def unrestricted_disbursements_allowed?
        false
      end

    end

  end

end
