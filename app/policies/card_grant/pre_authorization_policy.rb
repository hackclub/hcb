# frozen_string_literal: true

class CardGrant
  class PreAuthorizationPolicy < ApplicationPolicy
    def show?
      user&.auditor? || record.user == user || user_in_event?
    end

    def update?
      user&.auditor? || record.user == user || user_in_event?
    end

    def clear_screenshots?
      user&.auditor? || record.user == user || user_in_event?
    end

    private

    def user_in_event?
      record.event.users.include?(user)
    end

  end

end
