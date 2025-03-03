# frozen_string_literal: true

class User
  class SyncToLoopsJob < ApplicationJob
    queue_as :low

    def perform
      User.all.find_each(batch_size: 100) do |user|
        user.sync_with_loops
      end
    end

  end

end
