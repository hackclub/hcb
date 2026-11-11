# frozen_string_literal: true

class CardGrantSettingPolicy < ApplicationPolicy
  def update?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

end
