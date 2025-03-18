# frozen_string_literal: true

class OrganizerPosition
  module HasRole
    extend ActiveSupport::Concern
    included do
      # The enum values will allow us to have a hierarchy of roles in the future.
      # For example, managers have access to everything below them.
      enum :role, { reader: 5, member: 25, manager: 100 }
      validate :at_least_one_manager

      validate :signee_is_manager
    end

    private

    def at_least_one_manager
      event&.organizer_positions&.where(role: :manager)&.any?
    end

    def signee_is_manager
      return unless is_signee && role != "manager"

      errors.add(:role, "must be a manager because the user is a legal owner.")
    end
  end

end
