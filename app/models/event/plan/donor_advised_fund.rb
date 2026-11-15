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
    class DonorAdvisedFund < Standard
      def label
        "Donor-Advised Fund (#{revenue_fee_label})"
      end

      def description
        "Donor-Advised Funds (DAF) are funded by donors who then recommend grants. The organization contract signee should be the fund administrator, rather than the donor(s). A separate contract should be in-place between HCB and the donor(s)."
      end

      def contract_docuseal_template_id
        6398175
      end

      def contract_skip_prefills
        {
          "Contract Signee" => ["Telephone", "Email", "The Project"]
        }
      end

    end

  end

end
