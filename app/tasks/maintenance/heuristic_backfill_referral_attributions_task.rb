# frozen_string_literal: true

module Maintenance
  class HeuristicBackfillReferralAttributionsTask < MaintenanceTasks::Task
    # Heuristic second-pass backfill for Referral::Attribution rows that
    # BackfillReferralAttributionUsersTask cannot recover.
    #
    # Background: until the controller fix shipped, Users::FirstController
    # never bound Referral::Attribution rows to the new user. The new-user
    # branch called SessionsHelper#create_session, which builds a fresh
    # User::Session for the new user instead of binding user_id onto the
    # existing anonymous session. The anonymous session's user_id stayed
    # NULL forever, so the FK-based backfill (which joins on
    # user_sessions.user_id) skips these rows. The existing-user branch
    # never touched attributions at all.
    #
    # Strategy: iterate unattributed /first/welcome signups in time order
    # and, for each, claim the closest preceding orphan attribution within
    # WINDOW. Bind every orphan from the same anonymous session so that a
    # visitor who clicked multiple referral links in one sitting gets all
    # their clicks attributed correctly.
    #
    # The anchor event is whichever moment best approximates "they
    # submitted /first/welcome":
    #   - new-user branch: users.created_at (account is created on submit)
    #   - existing-user branch: the first Login row with
    #     state->>'purpose' = 'first', which Users::FirstController#create
    #     opens before redirecting to email verification.
    #
    # Caveat: this is heuristic. Two people signing up within seconds of
    # each other can have their clicks swapped. Aggregate per-team counts
    # are still close to truth because each user gets exactly one attribution
    # claimed. The task is safe to re-run; it never overwrites an
    # attribution that already has a user_id.
    WINDOW = 24.hours

    def collection
      User
        .where("EXISTS (SELECT 1 FROM event_affiliations ea WHERE ea.affiliable_type = 'User' AND ea.affiliable_id = users.id AND ea.name = 'first')")
        .where("NOT EXISTS (SELECT 1 FROM referral_attributions ra WHERE ra.user_id = users.id)")
        .order(:created_at)
    end

    def process(user)
      anchor = anchor_for(user)
      return unless anchor

      closest = Referral::Attribution
                .where(user_id: nil)
                .where(created_at: (anchor - WINDOW)..anchor)
                .order(created_at: :desc)
                .first
      return unless closest

      Referral::Attribution
        .where(user_id: nil, user_session_id: closest.user_session_id)
        .update_all(user_id: user.id, updated_at: Time.current)
    end

    private

    def anchor_for(user)
      if user.first_robotics_form?
        user.created_at
      else
        Login.where(user: user).where("state->>'purpose' = ?", "first").minimum(:created_at)
      end
    end

  end
end
