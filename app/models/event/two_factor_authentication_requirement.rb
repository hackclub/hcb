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
class Event
  module TwoFactorAuthenticationRequirement
    extend ActiveSupport::Concern

    GRACE_PERIOD = 7.days

    included do
      scope :requiring_two_factor_authentication, -> {
        where(id: Flipper[:require_two_factor_authentication_2026_11_24].actors_value.filter_map { |value| value.delete_prefix("Event;") if value.start_with?("Event;") })
      }
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

    def two_factor_authentication_deadline
      two_factor_authentication_required_at&.+(GRACE_PERIOD)
    end

    # Whether the user is out of time to enable two-factor authentication for
    # this organization. Members in this state are shut out of the organization
    # (see `OrganizerPosition.role_at_least?`) until they enable it.
    def two_factor_authentication_overdue_for?(user)
      return false if user.use_two_factor_authentication?

      deadline = two_factor_authentication_deadline
      deadline.present? && deadline.past?
    end

    def notify_two_factor_authentication_required(whodunnit:)
      users.find_each do |user|
        EventMailer.with(event: self, user:, whodunnit:).two_factor_authentication_required.deliver_later
      end
    end

  end

end
