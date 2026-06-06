# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class ControlPolicy < ApplicationPolicy
      def index?
        user.auditor? || (
          current_user_manager? || own_control?
        )
      end

      def create?
        user.admin? || (
           current_user_manager? &&
           !record.organizer_position.manager?
           # Don't have to make sure you're not setting the control on yourself as
           # if you're here it means you're a manager, but you can't set controls
           # against managers; so it's okay.
         )
      end

      def destroy?
        user.admin? || current_user_manager?
      end

      private

      def current_user_manager?
        OrganizerPosition.role_at_least?(user, record.organizer_position.event, :manager)
      end

      def own_control?
        user == record.organizer_position.user
      end

    end
  end

end
