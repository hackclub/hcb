# frozen_string_literal: true

class User
  module UpdateCardLocking
    class RecurringJob < ApplicationJob
      include ActiveJob::Continuable

      queue_as :low

      # A few users failing is normal. Past this, assume something systemic.
      FAILURE_TOLERANCE = 10

      # Errors fail the run rather than resuming it, so the tolerance check below
      # still surfaces a systemic failure.
      self.resume_errors_after_advancing = false

      # Every user is a checkpoint: when Sidekiq shuts down mid-sweep, the job
      # re-enqueues itself and the next execution picks up after the last user it
      # finished. The cursor carries the run's tallies so the tolerance check
      # covers the whole sweep, not just the last execution.
      def perform
        step :sweep do |step|
          next_user_id, processed, failed = step.cursor || [nil, 0, 0]

          User.card_locking_candidates.find_each(start: next_user_id, batch_size: 100) do |user|
            processed += 1
            failed += 1 unless update(user)
            step.set!([user.id + 1, processed, failed])
          end

          # Reporting each failure individually would otherwise let an outage look
          # like a successful run.
          raise "Card locking failed for #{failed} of #{processed} users" if failed > [FAILURE_TOLERANCE, processed / 5].max
        end
      end

      private

      # `find_each` iterates in primary key order, so without the per-user rescue a
      # single user who reliably raises would abort the batch and starve every user
      # after them, on every run. The rescue also supersedes ApplicationJob's
      # `discard_on(Twilio::REST::RestError)`, which can no longer see these errors.
      def update(user)
        ::UserService::RefreshReceiptDeadlines.new(user:).run
        ::UserService::UpdateCardLocking.new(user:).run
        ::UserService::SendCardLockingNotification.new(user:).run
        true
      rescue => e
        Rails.error.report(e, context: { user_id: user.id })
        false
      end

    end

  end

end
