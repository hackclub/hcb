# frozen_string_literal: true

# == Schema Information
#
# Table name: event_plans
#
#  id          :bigint           not null, primary key
#  aasm_state  :string           not null
#  inactive_at :datetime
#  type        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  event_id    :bigint           not null
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Event
  class Plan
    class SalaryAccount < FeeWaived
      def label
        "salary account"
      end

      def description
        "Used for living expense reimbursement. Has access to all standard features (except perks); and receipts are not required."
      end

      def omit_stats
        true
      end

      def card_lockable?
        false
      end

      def receipt_required?
        false
      end

    end

  end

end
