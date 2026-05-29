# frozen_string_literal: true

class User
  module UpdateCardLocking
    class RecurringJob < ApplicationJob
      queue_as :low
      def perform
        User.card_locking_candidates.find_each(batch_size: 100) do |user|
          ::UserService::UpdateCardLocking.new(user:).run
          ::UserService::SendCardLockingNotification.new(user:).run
        end
      end

    end

  end

end
