# frozen_string_literal: true

# An organization can require every member to use two-factor authentication.
# The requirement is the `require_two_factor_authentication_2026_11_24`
# Flipper flag enabled for the organization (an actor gate) from the feature
# previews page; the time that gate was created is the start of a grace
# period, after which members without two-factor authentication lose access
# to the organization until they turn it on.
#
# Only the per-organization actor gate counts. A boolean, group or percentage
# gate on the flag would turn it on for every organization at once with no
# emails and no deadline, so those are ignored.
#
# A requirement reaches down the tree: it covers the organization's own
# members and everyone with a position in a sub-organization beneath it. It
# does not reach up, so managers of a parent organization aren't locked out
# of it by a sub-organization's requirement.
class Event
  module TwoFactorAuthenticationRequirement
    extend ActiveSupport::Concern

    GRACE_PERIOD = 7.days

    included do
      scope :requiring_two_factor_authentication, -> { where(id: ids_requiring_two_factor_authentication) }
    end

    class_methods do
      def ids_requiring_two_factor_authentication
        Flipper[:require_two_factor_authentication_2026_11_24].actors_value.filter_map { |value| value.delete_prefix("Event;").to_i if value.start_with?("Event;") }
      end

      # A subquery of `leaves` plus every organization above them; the
      # upward counterpart of .self_and_descendant_ids.
      def self_and_ancestor_ids(leaves)
        unscoped
          .with_recursive(tree: [
                            unscoped.where(id: leaves).select(:id, :parent_id),
                            unscoped.joins("INNER JOIN tree ON events.id = tree.parent_id").select(:id, :parent_id)
                          ])
          .from("tree")
          .select(:id)
      end
    end

    def two_factor_authentication_required?
      Flipper[:require_two_factor_authentication_2026_11_24].actors_value.include?(flipper_id)
    end

    # When the requirement was turned on, read off the organization's actor
    # gate row. `nil` when the flag is off, or when it was enabled without a
    # persisted gate (e.g. the in-memory adapter in specs).
    def two_factor_authentication_required_at
      return nil unless two_factor_authentication_required?
      return @two_factor_authentication_required_at if defined?(@two_factor_authentication_required_at)

      @two_factor_authentication_required_at = Flipper::Adapters::ActiveRecord::Gate.find_by(feature_key: "require_two_factor_authentication_2026_11_24", key: "actors", value: flipper_id)&.created_at
    end

    # Whether this organization, or one above it, requires two-factor
    # authentication of its members.
    def requires_two_factor_authentication_of_members?
      Event.ids_requiring_two_factor_authentication.intersect?(ancestor_ids)
    end

    def two_factor_authentication_deadline
      two_factor_authentication_required_at&.+(GRACE_PERIOD)
    end

    # Whether the user is out of time to enable two-factor authentication for
    # this organization, because it or an organization above it requires it
    # of them and the grace period has passed. Users in this state are shut
    # out of the organization (see `OrganizerPosition.role_at_least?` and
    # `SessionsHelper#organizer_signed_in?`) until they enable it.
    def two_factor_authentication_overdue_for?(user)
      return false if user.use_two_factor_authentication?
      return false if Event.ids_requiring_two_factor_authentication.empty?

      @two_factor_authentication_overdue_for ||= {}
      return @two_factor_authentication_overdue_for[user.id] if @two_factor_authentication_overdue_for.key?(user.id)

      @two_factor_authentication_overdue_for[user.id] = user.events_requiring_two_factor_authentication.any? do |requiring_event|
        ancestor_ids.include?(requiring_event.id) && requiring_event.two_factor_authentication_deadline&.past?
      end
    end

    # Everyone this organization's requirement applies to: members here and
    # in every sub-organization beneath it.
    def users_required_to_use_two_factor_authentication
      User.where(id: OrganizerPosition.where(event_id: Event.self_and_descendant_ids(id)).select(:user_id))
    end

    def notify_two_factor_authentication_required(whodunnit:)
      users_required_to_use_two_factor_authentication.find_each do |user|
        EventMailer.with(event: self, user:, whodunnit:).two_factor_authentication_required.deliver_later
      end
    end

  end

end
