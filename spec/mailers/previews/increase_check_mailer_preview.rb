# frozen_string_literal: true

class IncreaseCheckMailerPreview < ActionMailer::Preview
  def notify_recipient
    IncreaseCheckMailer.with(check:).notify_recipient
  end

  def notify_stopped
    IncreaseCheckMailer.with(check: stopped_check).notify_stopped
  end

  def remind_recipient
    IncreaseCheckMailer.with(check: approved_check).remind_recipient
  end

  private

  def check
    IncreaseCheck.last
  end

  def stopped_check
    IncreaseCheck.where(column_status: :stopped).last
  end

  def approved_check
    IncreaseCheck.where.not(approved_at: nil).last
  end

end
