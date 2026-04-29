# frozen_string_literal: true

class EmburseCardPolicy < ApplicationPolicy
  def index?
    auditor?
  end

  def show?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || auditor?
  end

end
