# frozen_string_literal: true

class User
  class SyncToLoopsJob < ApplicationJob
    queue_as :low

    def perform
      User.all.find_each(batch_size: 100) do |user|
        UserService::SyncWithLoops.new(user_id: user.id).run
      end
    end

  end

end
