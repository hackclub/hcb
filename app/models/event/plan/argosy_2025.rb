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
    class Argosy2025 < SpendOnly
      def label
        "2025 Argosy grantee spend-only"
      end

      def features
        super - %w[promotions google_workspace]
      end

      def contract_docuseal_template_id
        1766872
      end

      def default_values
        { is_public: true }
      end

    end

  end

end
