# frozen_string_literal: true

class GrantPolicy < ApplicationPolicy
  def index?
    false
  end

  def new?
    false
  end

  def create?
    false
  end

  def approve?
    false
  end

  def reject?
    false
  end

  def additional_info_needed?
    false
  end

  def mark_fulfilled?
    false
  end

  def show?
    user&.auditor? || user == record.recipient
  end

  def activate?
    false
  end

  private

  def admin_or_user
    user&.admin? || record.event.users.include?(user)
  end


end
