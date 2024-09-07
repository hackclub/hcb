# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class ControlPolicy < ApplicationPolicy
      def index?
        return unless enabled?

        user.admin? || (
          current_user_manager? || own_control?
        )
      end

      def create?
        return unless enabled?

        user.admin? || (
           current_user_manager? &&
           !record.organizer_position.manager?
           # Don't have to make sure you're not setting the control on yourself as
           # if you're here it means you're a manager, but you can't set controls
           # against managers; so it's okay.
         )
      end

      def destroy?
        return unless enabled?

        user.admin? ||
          current_user_manager?

      end

      private

      def current_user_manager?
        OrganizerPosition.find_by(user:, event: record.organizer_position.event).manager?
      end

      def own_control?
        user == record.organizer_position.user
      end

      def enabled?
        Flipper.enabled?(:spending_controls_2024_06_03, record.organizer_position.event)
      end

    end
  end

end
