# frozen_string_literal: true

class User
  class SendCardLockingNotificationJob < ApplicationJob
    queue_as :low
    def perform(user:)
      ::UserService::SendCardLockingNotification.new(user:).run
    end

  end

end
