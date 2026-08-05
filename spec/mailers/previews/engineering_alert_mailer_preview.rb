# frozen_string_literal: true

class EngineeringAlertMailerPreview < ActionMailer::Preview
  def cards_locked
    user = User.first
    EngineeringAlertMailer.cards_locked(user:, overdue_count: 2, suppressed: false)
  end

  def cards_unlocked
    user = User.first
    EngineeringAlertMailer.cards_unlocked(user:, remaining_overdue_count: 0, suppressed: false)
  end

end
