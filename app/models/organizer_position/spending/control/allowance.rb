# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_position_spending_control_allowances
#
#  id                                     :bigint           not null, primary key
#  amount_cents                           :integer          not null
#  memo                                   :text
#  created_at                             :datetime         not null
#  updated_at                             :datetime         not null
#  authorized_by_id                       :bigint           not null
#  organizer_position_spending_control_id :bigint           not null
#
# Indexes
#
#  idx_org_pos_spend_ctrl_allows_on_authed_by_id           (authorized_by_id)
#  idx_org_pos_spend_ctrl_allows_on_org_pos_spend_ctrl_id  (organizer_position_spending_control_id)
#
# Foreign Keys
#
#  fk_rails_...  (authorized_by_id => users.id)
#  fk_rails_...  (organizer_position_spending_control_id => organizer_position_spending_controls.id)
#
class OrganizerPosition
  module Spending
    class Control
      class Allowance < ApplicationRecord
        belongs_to :control, class_name: "OrganizerPosition::Spending::Control", foreign_key: :organizer_position_spending_control_id, inverse_of: :allowances
        belongs_to :authorized_by, class_name: "User"
        monetize :amount_cents

        has_one :organizer_position, through: :control
        has_one :event, through: :organizer_position

        validate :balance_is_positive, on: :create
        validate :balance_is_non_zero, on: :create
        validates :amount_cents, numericality: { less_than_or_equal_to: 999_999_99 }

        private

        def balance_is_positive
          errors.add(:control, "balance must be positive") if control.balance_cents + amount_cents < 0
        end

        def balance_is_non_zero
          errors.add(:allowance, "must be nonzero") if amount_cents.zero?
        end

      end

    end
  end

end
