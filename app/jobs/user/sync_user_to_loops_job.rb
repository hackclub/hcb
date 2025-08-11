# frozen_string_literal: true

class User
  class SyncUserToLoopsJob < ApplicationJob
    queue_as :low

    def perform(user_id:, new_user: false)
      UserService::SyncWithLoops.new(user_id:, new_user:).run
    end

  end

end
