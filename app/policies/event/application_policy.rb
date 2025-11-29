# frozen_string_literal: true

class Event
  class ApplicationPolicy < ApplicationPolicy
    def create?
      record.user == user
    end

    def show?
      record.user == user
    end

    alias_method :update?, :show?
    alias_method :personal_info?, :show?
    alias_method :project_info?, :show?

  end

end
