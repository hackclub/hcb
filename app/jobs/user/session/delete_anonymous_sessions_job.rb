# frozen_string_literal: true

class User
  class Session
    # Deletes the throwaway sessions minted for visitors who never signed in.
    #
    # These came from the global `ensure_created_session` before_action: every
    # request from a client that didn't retain cookies (crawlers, webhook
    # senders, API consumers) created a session row plus a matching PaperTrail
    # version, growing `user_sessions` into the tens of millions of rows.
    #
    # `ensure_created_session` has since been narrowed to referral link clicks,
    # which stops the bulk of these from being created, but a click that never
    # leads to a signup still leaves one behind. So this runs on a schedule
    # rather than once, draining the existing backlog along the way.
    class DeleteAnonymousSessionsJob < ApplicationJob
      queue_as :low

      BATCH_SIZE = 1_000

      # Bounds the work per run: keeps an invocation short enough that the
      # schedule can't start a second run on top of a first (nothing else
      # enforces uniqueness), and spreads out the dead tuples and WAL a bulk
      # delete generates so autovacuum can keep pace.
      MAX_PER_RUN = 500_000

      # @return [Integer] the number of sessions deleted
      def perform(max_per_run: MAX_PER_RUN)
        deleted = 0

        deletable.in_batches(of: BATCH_SIZE) do |batch|
          deleted += purge(batch.pluck(:id))
          break if deleted >= max_per_run
        end

        deleted
      end

      private

      # Sessions that never became real ones:
      #
      #   - `user_id` is nil, so the session never authenticated. Nothing
      #     assigns a user to an already-persisted session (signing in mints a
      #     new one), so this can't be a session that signed in and detached.
      #   - it has already expired, so no visitor is mid-signup on it.
      #   - no `Referral::Attribution` points at it. Those carry signup
      #     attribution, and the FK is ON DELETE NO ACTION, so deleting one
      #     would raise anyway.
      def deletable
        User::Session
          .where(user_id: nil)
          .expired
          .where.not(id: Referral::Attribution.where.not(user_session_id: nil).select(:user_session_id))
      end

      # Every reference to `user_sessions` was audited before writing this:
      # incoming foreign keys, `logins.user_session_id` (which has no FK, only
      # `Login`'s own validations), `governance_request_contexts`, and every
      # polymorphic `*_type` column. Only two things point at anonymous
      # sessions, and both go with them:
      #
      #   - PaperTrail versions. One per insert, plus an update version for a
      #     session that went through `SessionsHelper#sign_out`, which uses
      #     `update` rather than `update_columns`.
      #   - `user_session.create` activities with a null owner, null recipient
      #     and no parameters, left by a callback that fired for anonymous
      #     sessions until bf0e737f4 guarded it.
      #
      # Rows are removed with `delete_all` so the PaperTrail callback doesn't
      # write a fresh version per destroy. The three deletes share a
      # transaction so a failure on the last one can't leave a session alive
      # with its audit trail already stripped.
      #
      # @return [Integer] the number of sessions deleted
      def purge(ids)
        return 0 if ids.empty?

        User::Session.transaction do
          PaperTrail::Version.where(item_type: "User::Session", item_id: ids).delete_all
          PublicActivity::Activity.where(trackable_type: "User::Session", trackable_id: ids).delete_all
          User::Session.where(id: ids).delete_all
        end
      end

    end

  end

end
