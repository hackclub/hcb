# frozen_string_literal: true

# An organization can require every member to use two-factor authentication.
# The requirement is a Flipper flag enabled per organization from the feature
# previews page; the time the flag was enabled (the gate's `created_at`) is
# the start of a grace period, after which members without two-factor
# authentication lose access to the organization until they turn it on.
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
      Flipper.enabled?(:require_two_factor_authentication_2026_11_24, self)
    end

    # When the requirement was turned on, read off the Flipper gate. `nil`
    # when the flag is off, or when it was enabled somewhere without a
    # persisted gate (e.g. the in-memory adapter in specs).
    def two_factor_authentication_required_at
      return nil unless two_factor_authentication_required?

      @two_factor_authentication_required_at ||= begin
        gates = Flipper::Adapters::ActiveRecord::Gate.where(feature_key: "require_two_factor_authentication_2026_11_24")
        gates.find_by(key: "actors", value: flipper_id)&.created_at || gates.find_by(key: "boolean")&.created_at
      end
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
