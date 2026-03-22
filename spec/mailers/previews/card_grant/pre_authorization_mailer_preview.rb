# frozen_string_literal: true

class CardGrant
  class PreAuthorizationMailerPreview < ActionMailer::Preview
    def notify_fraudulent
      PreAuthorizationMailer.with(pre_authorization: PreAuthorization.last).notify_fraudulent
    end

  end

end
