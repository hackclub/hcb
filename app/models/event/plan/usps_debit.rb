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
    class USPSDebit < Internal
      def label = "HQ USPS debit"

      validate do
        unless event_id == EventMappingEngine::EventIds::HQ_USPS_OPS
          errors.add(:event, "must be Theseus USPS Operating Account")
        end
      end

      def description
        "account for HQ's USPS integration - no receipts (if it gets card-locked we're federally cooked)"
      end

      def features = %w[cards account_number transfers documentation unrestricted_disbursements front_disbursements]

      def card_lockable? = false

      def receipts_required? = false

    end

  end

end
