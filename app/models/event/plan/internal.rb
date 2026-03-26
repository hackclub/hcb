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
    class Internal < FeeWaived
      def label
        "HCB internal organization"
      end

      def description
        "FOR ENGINEERING/TRANSACTION ENGINE USE ONLY. 👻 oo scary! you're looking at the internal workings of HCB. shield your eyes, you may not like what you see."
      end

      def features
        Event::Plan.available_features
      end

      def requires_reimbursement_expense_categorization?
        true
      end

      def omit_stats
        true
      end

      def contract_required?
        false
      end

    end

  end

end
