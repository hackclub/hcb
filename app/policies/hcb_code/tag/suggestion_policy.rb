# frozen_string_literal: true

class HcbCode
  module Tag
    class SuggestionPolicy < ApplicationPolicy
      def accept?
        admin_or_user?
      end

      def reject?
        admin_or_user?
      end

      private

      def admin_or_user?
        user&.admin? || record.tag.event.users.include?(user)
      end

    end
  end

end
