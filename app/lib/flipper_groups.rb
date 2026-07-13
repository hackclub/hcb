# frozen_string_literal: true

# Membership logic behind the Flipper groups registered in
# config/initializers/flipper_groups.rb.
#
# Each predicate takes an already-unwrapped actor (the initializer unwraps
# Flipper::Types::Actor before calling). A flag can be checked against a User or
# an Event actor, so each predicate guards on the actor class it expects and any
# other type falls through to false. This also avoids User/Event id collisions,
# since ids only overlap across classes.
#
# The resolved id sets are cached because a flag using one of these groups may be
# checked on every request. Membership changes come through the org tree in code
# or through OrganizerPositions, neither of which we can cheaply invalidate on, so
# a short TTL keeps the sets fresh enough. The cache keys embed a digest of their
# code-defined source (the org tree, the HQ root ids) so a deploy that edits the
# source busts the cache immediately rather than serving the old set for up to a
# TTL after the new code ships.
module FlipperGroups
  # Root events representing Hack Club HQ. Their managers (and the managers of
  # their descendants) are HQ-descendant users; the events themselves and their
  # descendants are HQ-descendant organizations. Kept as ids so the set survives
  # an event rename.
  HQ_ROOT_EVENT_IDS = [183, 9511].freeze

  CACHE_TTL = 1.hour

  module_function

  def hcb_team?(actor)
    in_set?(actor, User, hcb_team_user_ids)
  end

  def hcb_engineer?(actor)
    in_set?(actor, User, hcb_engineer_user_ids)
  end

  # Any user with an @hackclub.com email. Matched directly off the address (no
  # cached id set needed), exact-domain only: subdomains like
  # someone@events.hackclub.com are not included.
  def hackclub_email?(actor)
    return false unless actor.is_a?(User)

    actor.email.to_s.downcase.end_with?("@hackclub.com")
  end

  # Any admin, superadmin, or auditor. auditor? already returns true for the admin
  # and superadmin roles, and it honors the "pretend to be a normal user"
  # preference, so an admin in pretend mode does not match.
  def admin_or_auditor?(actor)
    return false unless actor.is_a?(User)

    actor.auditor?
  end

  def hq_descendant_user?(actor)
    return false unless actor.is_a?(User)
    # Admins and auditors always qualify, ignoring an admin's "pretend to be a
    # normal user" preference (this gates internal HQ tooling, not user-facing
    # behavior, so pretend mode shouldn't hide it).
    return true if actor.admin_override_pretend?

    # Not cached across requests so a revoked OrganizerPosition takes effect
    # immediately. Rails' per-request SQL query cache collapses repeated checks
    # within a single request to one query.
    managed_event_ids = actor.organizer_positions.manager_access.pluck(:event_id)
    managed_event_ids.any? { |event_id| hq_event_ids.include?(event_id) }
  end

  def hq_descendant_organization?(actor)
    in_set?(actor, Event, hq_event_ids)
  end

  def in_set?(actor, klass, ids)
    actor.is_a?(klass) && ids.include?(actor.id)
  end

  def hcb_team_user_ids
    fetch_id_set("flipper_groups/hcb_team_user_ids/#{HackClub::OrgChart::DIGEST}") do
      HackClub::OrgChart.user_ids.to_set
    end
  end

  def hcb_engineer_user_ids
    fetch_id_set("flipper_groups/hcb_engineer_user_ids/#{HackClub::OrgChart::DIGEST}") do
      HackClub::OrgChart.user_ids(:gary).to_set
    end
  end

  # {183, 9511} plus their descendants (manager access flows downward), as a Set
  # of ids. Ancestors are intentionally excluded: managing an ancestor does not
  # mean managing HQ.
  def hq_event_ids
    fetch_id_set("flipper_groups/hq_event_ids/#{HQ_ROOT_EVENT_IDS.join('-')}") do
      HQ_ROOT_EVENT_IDS.flat_map { |event_id|
        event = Event.find_by(id: event_id)
        if event.nil?
          # A hardcoded root going missing is a real "someone should know" event,
          # not something to swallow into an empty result.
          Rails.error.report(StandardError.new("[FlipperGroups] HQ root event #{event_id} not found"))
          next []
        end

        [event.id] + event.descendant_ids
      }.uniq.to_set
    end
  end

  # Reads an id set from the cache, recomputing on a miss. An unexpectedly-empty
  # result is reported and returned WITHOUT being cached, so a transient failure
  # (a DB blip, a missing root) self-heals on the next request instead of sticking
  # for a full TTL. None of these sets are ever legitimately empty.
  def fetch_id_set(cache_key)
    cached = Rails.cache.read(cache_key)
    return cached if cached.present?

    ids = yield
    if ids.empty?
      Rails.error.report(StandardError.new("[FlipperGroups] #{cache_key} resolved to an empty set; not caching"))
      return ids
    end

    Rails.cache.write(cache_key, ids, expires_in: CACHE_TTL)
    ids
  end
end
