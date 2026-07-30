# frozen_string_literal: true

class LegalEntityPolicy < ApplicationPolicy
  def show?
    user.auditor? || member?
  end

  def replace?
    user.admin? || member?
  end

  # `create_from_tax_form` moves the entity's pending payments onto a new entity
  # owned solely by the caller, and it looks the entity up from a user-supplied id.
  # So this must be strict ownership, not replace?'s `admin? || member?`: an admin
  # who is not a member must not be able to redirect a stranger's pending payments.
  def switch?
    member?
  end

  # Nobody but the taxpayer may see their TIN, not even the last four digits, and
  # not even an admin or an auditor.
  def show_masked_tin?
    member?
  end

  private

  def member?
    record.users.include?(user)
  end

end
