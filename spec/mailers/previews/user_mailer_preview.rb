# frozen_string_literal: true

class UserMailerPreview < ActionMailer::Preview
  def onboarded
    user = User.where.not(full_name: [nil, ""]).last

    UserMailer.onboarded(user:)
  end

  def incomplete_payout_method
    payout_method = LegalEntity::PayoutMethod.where(details_type: LegalEntity::PayoutMethod::WiseTransfer.name).last

    UserMailer.incomplete_payout_method(user: payout_method.legal_entity.users.first, payout_method:)
  end

end
