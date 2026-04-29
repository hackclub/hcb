# frozen_string_literal: true

class EventTagPolicy < ApplicationPolicy
  def create?
    admin?
  end

  def destroy?
    admin?
  end

  def toggle_event_tag?
    admin?
  end

end
