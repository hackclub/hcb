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
      record.user == user || user.admin?
    end

    alias_method :personal_info?, :show?
    alias_method :project_info?, :show?
    alias_method :review?, :show?

    alias_method :submit?, :update?

  end

end
