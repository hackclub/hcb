# frozen_string_literal: true

class OrganizerPosition
  module HasRole
    extend ActiveSupport::Concern
    included do
      # The enum values will allow us to have a hierarchy of roles in the future.
      # For example, managers have access to everything below them.
      enum :role, { reader: 5, member: 25, manager: 100, supervisor: 200 }
      validate :at_least_one_manager_or_supervisor

      validate :signee_is_manager_or_supervisor
    end

    private

    def at_least_one_manager_or_supervisor
      if event&.plan&.supervisor_required?
        errors.add(:base, "A supervisor is required for this event.") unless event&.organizer_positions&.where(role: :supervisor)&.where&.not(id: self.id)&.any? || role == "supervisor"
      else
        errors.add(:base, "A manager is required for this event.") unless event&.organizer_positions&.where(role: :manager)&.where&.not(id: self.id)&.any? || role == "manager"
      end
    end

    def signee_is_manager_or_supervisor
      return unless is_signee && !role.in?(["manager", "supervisor"])

      errors.add(:role, "must be a manager because the user is a legal owner.")
    end
  end

end
