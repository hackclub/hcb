# frozen_string_literal: true

class CardGrantTemplatePolicy < ApplicationPolicy
  def show?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def create?
    (user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)) && record.event.plan.card_grants_enabled?
  end

  alias_method :update?, :create?

  def destroy?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

end
