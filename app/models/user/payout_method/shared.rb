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
        after_create_commit :create_legal_entity_payout_method

        validate do
          if User::PayoutMethod::UNSUPPORTED_METHODS.include?(self.class)
            errors.add(:base, "#{self.unsupported_details[:reason]} Please choose another method.")
          end
        end

        delegate :unsupported?, to: :class
        delegate :unsupported_details, to: :class

        def create_legal_entity_payout_method
          legal_entity = user.legal_entities.find_by(entity_type: :person)
          return unless legal_entity

          details_class = self.class.name.sub(/\AUser::/, "LegalEntity::").safe_constantize
          return unless LegalEntity::PayoutMethod::ALL_METHODS.include?(details_class)

          details = details_class.find_by(id:)
          return unless details

          LegalEntity::PayoutMethod.find_or_create_by!(legal_entity:, details:) do |payout_method|
            payout_method.default = true
          end
        end
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
