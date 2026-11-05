# frozen_string_literal: true

module Maintenance
  class FixUserSessionTimestampsTask < MaintenanceTasks::Task
    TIMESTAMP_ATTRIBUTES = %w[expiration_at signed_out_at].freeze
    # `signed_out_at` was introduced in January 2025; the fix merged on April 8, 2026.
    INCIDENT_WINDOW = Time.utc(2025, 1, 1)...Time.utc(2026, 4, 9)

    def collection
      User::Session
        .where(signed_out_at: INCIDENT_WINDOW)
        .where("ABS(EXTRACT(EPOCH FROM (signed_out_at - expiration_at))) <= 1")
    end

    def process(session)
      corrupted_at = session.signed_out_at
      corrupted_at = [corrupted_at, session.expiration_at].max
      earliest_timestamp = [session.signed_out_at, session.expiration_at].min

      return if session.versions.where("created_at >= ?", earliest_timestamp).any? do |version|
        changes = version.object_changes || {}
        TIMESTAMP_ATTRIBUTES.any? { |attribute| changes.key?(attribute) }
      end

      user = User.find_by(id: session.user_id) if session.user_id
      return if locked_at_same_time?(user, corrupted_at)
      return if user&.verified? && session.unverified?

      version = session.versions
                       .where("created_at < ?", earliest_timestamp)
                       .order(created_at: :desc, id: :desc)
                       .first
      return unless version
      return if session.last_seen_at && version.created_at <= session.last_seen_at

      object = version.object || {}
      object_changes = version.object_changes || {}
      historical_values = TIMESTAMP_ATTRIBUTES.index_with do |attribute|
        if object_changes.key?(attribute)
          object_changes[attribute].last
        elsif object.key?(attribute)
          object[attribute]
        elsif attribute == "signed_out_at"
          nil
        end
      end
      return unless historical_values["expiration_at"]

      expiration_at = User::Session.type_for_attribute("expiration_at").cast(historical_values["expiration_at"])
      signed_out_at = User::Session.type_for_attribute("signed_out_at").cast(historical_values["signed_out_at"])

      # update_all doesn't create PaperTrail versions. Use a snapshot from after
      # the session's latest activity so its untracked expiry refresh is included.
      return if expiration_at > corrupted_at

      session.update!(expiration_at:, signed_out_at:)
    end

    private

    def locked_at_same_time?(user, timestamp)
      return false unless user

      user.versions.where(created_at: (timestamp - 1.minute)..(timestamp + 1.minute)).any? do |version|
        (version.object_changes || {}).dig("locked_at")&.last.present?
      end
    end

  end
end
