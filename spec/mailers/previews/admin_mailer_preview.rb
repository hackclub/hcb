# frozen_string_literal: true

class AdminMailerPreview < ActionMailer::Preview
  delegate :reminders, to: :AdminMailer

end
