# frozen_string_literal: true

class UserMailerPreview < ActionMailer::Preview
  def onboarded
    user = User.where.not(full_name: [nil, ""]).last

    UserMailer.onboarded(user:)
  end

end
