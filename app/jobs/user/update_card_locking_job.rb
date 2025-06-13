# frozen_string_literal: true

class User
  class UpdateCardLockingJob < ApplicationJob
    queue_as :low
    def perform(user:)
      ::UserService::UpdateCardLocking.new(user:).run
    end

  end

end
