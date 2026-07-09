# frozen_string_literal: true

class User
  module UpdateCardLocking
    class RecurringJob < ApplicationJob
      queue_as :low
      # `find_each` iterates in primary key order, so without this rescue a single
      # user who reliably raises (a Twilio outage, an undeliverable mailer) would
      # abort the batch and starve every user after them, on every run.
      def perform
        User.card_locking_candidates.find_each(batch_size: 100) do |user|
          ::UserService::UpdateCardLocking.new(user:).run
          ::UserService::SendCardLockingNotification.new(user:).run
        rescue => e
          Rails.error.report(e, context: { user_id: user.id })
        end
      end

    end

  end

end
