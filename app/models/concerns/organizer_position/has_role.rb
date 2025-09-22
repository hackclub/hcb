# frozen_string_literal: true

class OrganizerPosition
  module HasRole
    extend ActiveSupport::Concern
    included do
      # The enum values will allow us to have a hierarchy of roles in the future.
      # For example, managers have access to everything below them.

      enum :role, {
        reader: 5,
        member: 25,
        manager: 100,
        owner: 1000
      }

      roles.each do |role_name, role_value|
        scope "#{role_name}_access", -> { where("role >= ?", role_value) }
      end

      validate :at_least_one_owner

      validate :signee_is_owner
    end

    private

    def at_least_one_owner
      event&.organizer_positions&.where(role: :owner)&.any?
    end

    def signee_is_owner
      return unless is_signee && role != "owner"

      errors.add(:role, "must be an owner because the user is a legal owner.")
    end
  end

end
