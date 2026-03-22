# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  def create?
    OrganizerPosition.role_at_least?(user, record, :member)
  end

  def update?
    member?
  end

  def destroy?
    member?
  end

  def toggle_tag?
    member?
  end

  private

  def auditor?
    user&.auditor?
  end

  def reader?
    OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def member?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

end
