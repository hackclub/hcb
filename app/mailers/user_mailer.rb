# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def onboarded(user:)
    @user = user

    mail to: @user.email, subject: "Welcome to HCB!"
  end

  def incomplete_payout_method(user:, payout_method:)
    @user = user
    @payout_method = payout_method

    mail to: @user.email_address_with_name, subject: "[Action Required] Update your payout method to keep getting paid"
  end

end
