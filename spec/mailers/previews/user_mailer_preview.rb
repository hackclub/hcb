# frozen_string_literal: true

class UserMailerPreview < ActionMailer::Preview
  def onboarded
    user = User.last

    UserMailer.onboarded(user:)
  end
end
