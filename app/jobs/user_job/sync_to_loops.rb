# frozen_string_literal: true

module UserJob
  class SyncToLoops < ApplicationJob
    queue_as :low

    def perform
      User.all.find_each(batch_size: 100) do |user|
        user.sync_with_loops
      end
    end

  end
end
