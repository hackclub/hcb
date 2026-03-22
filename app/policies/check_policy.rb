# frozen_string_literal: true

class CheckPolicy < ApplicationPolicy
  def show?
    is_public || auditor_or_user
  end

  private

  def auditor_or_user
    user&.auditor? || record.lob_address.event.users.include?(user)
  end

  def is_public
    record.lob_address.event.is_public?
  end

end
