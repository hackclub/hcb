# frozen_string_literal: true

class User
  module UpdateCardLocking
    class RecurringJob < ApplicationJob
      queue_as :low

      # A few users failing is normal. Past this, assume something systemic.
      FAILURE_TOLERANCE = 10

      # `find_each` iterates in primary key order, so without the per-user rescue a
      # single user who reliably raises would abort the batch and starve every user
      # after them, on every run. The rescue also supersedes ApplicationJob's
      # `discard_on(Twilio::REST::RestError)`, which can no longer see these errors.
      def perform
        processed = 0
        failed = 0

        User.card_locking_candidates.find_each(batch_size: 100) do |user|
          processed += 1
          ::UserService::RefreshReceiptDeadlines.new(user:).run
          ::UserService::UpdateCardLocking.new(user:).run
          ::UserService::SendCardLockingNotification.new(user:).run
        rescue => e
          failed += 1
          Rails.error.report(e, context: { user_id: user.id })
        end

        # Reporting each failure individually would otherwise let an outage look
        # like a successful run.
        raise "Card locking failed for #{failed} of #{processed} users" if failed > [FAILURE_TOLERANCE, processed / 5].max
      end

    end

  end

end
