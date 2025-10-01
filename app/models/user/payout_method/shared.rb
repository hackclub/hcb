# frozen_string_literal: true

# == Schema Information
#
# Table name: user_payout_method_paypal_transfers
#
#  id              :bigint           not null, primary key
#  recipient_email :text             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class User
  module PayoutMethod
    module Shared
      extend ActiveSupport::Concern
      included do
        has_one :user, inverse_of: :payout_method, as: :payout_method
        after_save_commit -> {
          Reimbursement::PayoutHolding.where(report: user.reimbursement_reports).failed.each(&:mark_settled!)
          Employee::Payment.where(employee: user.jobs).failed.each(&:mark_approved!)
        }

        validate do
          if User::PayoutMethod::UNSUPPORTED_METHODS.include?(self.class)
            errors.add(:base, "#{self.unsupported_details[:reason]} Please choose another method.")
          end
        end

        delegate :unsupported?, to: :class
        delegate :unsupported_details, to: :class
      end

      class_methods do
        def unsupported?
          User::PayoutMethod::UNSUPPORTED_METHODS.key?(self)
        end

        def unsupported_details
          User::PayoutMethod::UNSUPPORTED_METHODS[self]
        end
      end
    end
  end

end
