# frozen_string_literal: true

class SponsorPolicy < ApplicationPolicy
  def index?
    auditor_or_reader?
  end

  # sponsors can never be seen in transparency mode
  def show?
    auditor_or_reader?
  end

  def new?
    admin_or_member?
  end

  def create?
    admin_or_member?
  end

  def edit?
    admin_or_member?
  end

  def update?
    admin_or_member?
  end

  def destroy?
    admin_or_member?
  end

  def permitted_attributes
    attrs = [
      :name,
      :contact_email,
      :address_line1,
      :address_line2,
      :address_city,
      :address_state,
      :address_postal_code,
      :address_country,
      :id
    ]

    attrs << :event_id if user&.admin?

    attrs
  end

  private

  def auditor_or_reader?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record&.event, :reader)
  end

  def admin_or_member?
    user&.admin? || OrganizerPosition.role_at_least?(user, record&.event, :member)
  end

end
