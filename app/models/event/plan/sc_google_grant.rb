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
    class ScGoogleGrant < Standard
      def label
        "South Carolina Google Grant"
      end

      def contract_docuseal_template_id
        2672920
      end

      def contract_skip_prefills
        {
          "Contract Signee" => ["The Project"],
          "HCB"             => ["HCB ID", "Signature"]
        }
      end

    end

  end

end
