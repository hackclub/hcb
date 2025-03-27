# frozen_string_literal: true

class SponsorPolicy < ApplicationPolicy
  def index?
    user.auditor?
  end

  def show?
    user.auditor?
  end

  def new?
    user.admin?
  end

  def create?
    user.admin?
  end

  def edit?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy
    user.admin?
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

    attrs << :event_id if user.admin?

    attrs
  end

  private

  def user_has_position?
    record.event&.users&.include?(user)
  end

end
