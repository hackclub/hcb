# frozen_string_literal: true

class Event
  class ApplicationPolicy < ApplicationPolicy
    def create?
      record.user == user
    end

    def edit?
      record.user == user
    end

    alias_method :step?, :edit?
    alias_method :update?, :edit?

  end

end
