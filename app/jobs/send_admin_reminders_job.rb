# frozen_string_literal: true

class SendAdminRemindersJob < ApplicationJob
  queue_as :low
  def perform
    AdminMailer.reminders.deliver_later
  end

end
