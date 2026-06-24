# frozen_string_literal: true

class User
  class UpdateCardLockingJob < ApplicationJob
    queue_as :low
    def perform(user:, unlock_only: false)
      ::UserService::UpdateCardLocking.new(user:, unlock_only:).run
    end

  end

end
