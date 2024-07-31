# frozen_string_literal: true

class CheckPolicy < ApplicationPolicy
  def show?
    is_public || admin_or_user
  end

  private

  def admin_or_user
    user&.admin? || record.lob_address.event.users.include?(user)
  end

  def is_public
    record.lob_address.event.is_public?
  end

end
