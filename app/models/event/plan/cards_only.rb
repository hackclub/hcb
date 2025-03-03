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
    class CardsOnly < Standard
      def label
        "card-only"
      end

      def description
        "Only has access to cards for spending and can't raise money, often used for one-off events like Outernet or Winter Hardware Wonderland."
      end

      def features
        %w[cards]
      end

      def omit_stats
        false
      end

    end

  end

end
