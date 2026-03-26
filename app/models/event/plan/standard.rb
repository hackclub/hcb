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
    class Standard < Plan
      def revenue_fee
        0.07
      end

      def label
        "full fiscal sponsorship (#{revenue_fee_label})"
      end

      def description
        if self.instance_of?(Event::Plan::Standard)
          "Has access to all standard features, used for most organizations."
        else
          "Has access to all standard features"
        end
      end

      def features
        Event::Plan.available_features - %w[card_grants unrestricted_disbursements front_disbursements]
      end

      def receipts_required?
        true
      end

      def exempt_from_wire_minimum?
        false
      end

      def requires_reimbursement_expense_categorization?
        false
      end

      def omit_stats
        false
      end

      def writeable?
        true # false if an organization should be read-only
      end

      def hidden?
        false
      end

      def mileage_rate(date)
        return 67 if date < Date.new(2025, 1, 1)
        return 70 if date < Date.new(2025, 3, 27)
        return 14 if date < Date.new(2025, 4, 11) # https://hackclub.slack.com/archives/C047Y01MHJQ/p1743055747682219

        70
      end

      def contract_required?
        true
      end

      def card_lockable?
        true
      end

      def contract_docuseal_template_id
        487784
      end

      def contract_skip_prefills
        {}
      end

    end

  end

end
