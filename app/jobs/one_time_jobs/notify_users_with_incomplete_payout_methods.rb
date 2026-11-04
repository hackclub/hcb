# frozen_string_literal: true

module OneTimeJobs
  # Emails users whose default payout method is missing a field the processor now requires
  # (e.g. a Wise recipient's date of birth). Payouts to those methods are held until it's added.
  class NotifyUsersWithIncompletePayoutMethods < ApplicationJob
    def perform
      LegalEntity::PayoutMethod
        .unarchived
        .where(default: true, details_type: LegalEntity::PayoutMethod::WiseTransfer.name)
        .includes(:details, legal_entity: :users)
        .find_each do |payout_method|
          next unless payout_method.incomplete?

          payout_method.legal_entity.users.each do |user|
            UserMailer.incomplete_payout_method(user:, payout_method:).deliver_later
          end
        rescue => e
          Rails.error.report(e)
        end
    end

  end
end
