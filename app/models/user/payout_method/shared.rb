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
          Employee::Payment.where(employee: user.jobs).failed.each(&:mark_admin_approved!)
        }
      end
    end
  end

end
