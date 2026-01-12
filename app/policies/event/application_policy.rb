# frozen_string_literal: true

class Event
  class ApplicationPolicy < ApplicationPolicy
    def create?
      record.user == user
    end

    def show?
      record.user == user || user.auditor?
    end

    def update?
      return true if user.admin?
      return record.user == user if record.draft?

      false
    end

    alias_method :personal_info?, :show?
    alias_method :project_info?, :show?
    alias_method :agreement?, :show?
    alias_method :review?, :show?

    alias_method :submit?, :update?

  end

end
