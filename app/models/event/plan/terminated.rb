# frozen_string_literal: true

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
    class Terminated < Standard
      def label
        "terminated"
      end

      def description
        "The organization, including all of its cards, is frozen and hidden."
      end

      def features
        %w[documentation]
      end

      def writeable?
        false
      end

      def hidden?
        true
      end

    end

  end

end
