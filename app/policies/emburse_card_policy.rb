# frozen_string_literal: true

class EmburseCardPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def show?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || user&.auditor?
  end

end
