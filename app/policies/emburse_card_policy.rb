# frozen_string_literal: true

class EmburseCardPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def show?
    record.event.users.include?(user) || user&.auditor?
  end

end
