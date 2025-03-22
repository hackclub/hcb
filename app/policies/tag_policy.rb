# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  def create?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def destroy?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def toggle_tag?
    OrganizerPosition.role_at_least?(user, :member)
  end

end
