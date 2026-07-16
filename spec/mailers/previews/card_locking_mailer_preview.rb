# frozen_string_literal: true

class CardLockingMailerPreview < ActionMailer::Preview
  def cards_locked
    CardLockingMailer.cards_locked(user: User.first)
  end

  def cards_unlocked
    CardLockingMailer.cards_unlocked(user: User.first)
  end

  def warning
    CardLockingMailer.warning(user: User.first)
  end

end
