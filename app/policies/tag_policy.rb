# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  def create?
    OrganizerPosition.role_at_least?(user, record, :member)
  end

  def update?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  def destroy?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  def toggle_tag?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
