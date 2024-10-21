# frozen_string_literal: true

# == Schema Information
#
# Table name: event_plans
#
#  id         :bigint           not null, primary key
#  aasm_state :string
#  plan_type  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
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
    class SpendOnly < Standard
      def label
        "spend-only"
      end

      def description
        "All incoming money is blocked."
      end

      def features
        %w[cards transfers promotions google_workspace documentation reimbursements]
      end

    end

  end

end
