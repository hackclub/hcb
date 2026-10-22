# frozen_string_literal: true

class CardGrantMailerPreview < ActionMailer::Preview
  def card_grant_notification
    CardGrantMailer.with(card_grant:).card_grant_notification
  end

  def card_grant_expiry_notification
    CardGrantMailer.with(card_grant:, expiry_time: "1 month").card_grant_expiry_notification
  end

  private

  def card_grant
    CardGrant.last
  end

end
