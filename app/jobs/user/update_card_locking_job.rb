# frozen_string_literal: true

class User
  class UpdateCardLockingJob < ApplicationJob
    queue_as :low
    def perform(user:, unlock_only: false, notify_progress: false)
      ::UserService::UpdateCardLocking.new(user:, unlock_only:, notify_progress:).run
    end

  end

end
