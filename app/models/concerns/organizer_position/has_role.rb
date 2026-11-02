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
    end

    # True for managers and anyone above them (i.e. owners)
    def manager_access?
      role.present? && self.class.roles[role] >= self.class.roles[:manager]
    end

  end

end
