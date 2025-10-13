# frozen_string_literal: true

class User
  class SendCardLockingNotificationJob < ApplicationJob
    queue_as :low
    def perform(user:, event:)
      if event.plan.receipts_required?
        ::UserService::SendCardLockingNotification.new(user:).run
      end
    end

  end

end
