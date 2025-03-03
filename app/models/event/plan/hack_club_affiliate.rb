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
    class HackClubAffiliate < FeeWaived
      def label
        "Hack Club affiliated project"
      end

      def description
        "Has access to all standard features with no fees."
      end

      def exempt_from_wire_minimum?
        true
      end

      def requires_reimbursement_expense_categorization?
        true
      end

      def omit_stats
        true
      end

    end

  end

end
