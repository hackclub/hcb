# frozen_string_literal: true

class OrganizerPositionInvitePolicy < ApplicationPolicy
  # An invitation is visible to the organization's readers and to the person
  # invited. Not published by v3, so no transparency branch — who has been
  # invited is organizer information.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.auditor?
      return scope.none if user.nil?

      scope.where(event_id: user.readable_event_ids.to_a).or(scope.where(user:))
    end

  end

  def index?
    user&.auditor? || record.event&.users&.include?(user)
  end

  def new?
    admin_or_manager?
  end

  def create?
    admin_or_manager?
  end

  def show?
    user&.auditor? || record.user == user
  end

  def accept?
    record.user == user
  end

  def reject?
    record.user == user
  end

  def cancel?
    admin_or_manager? || (record.sender == user && record.event&.users&.include?(user))
  end

  def destroy?
    cancel?
  end

  def resend?
    admin_or_manager? || (record.sender == user && record.event&.users&.include?(user))
  end

  def change_position_role?
    admin_or_manager? && !record.signee?
  end

  def send_contract?
    user&.admin?
  end


  # See ApplicationPolicy#visible_attributes. An invitation is not published by
  # v3 and is not part of a transparent organization's public face — knowing
  # who has been invited is organizer information.
  def visible_attributes
    @visible_attributes ||= begin
      return [] unless event_reader? || !!user&.auditor? || record.user == user

      %i[accepted role sender sender_id invitee invitee_id organization organization_id]
    end
  end

  private

  def admin_or_manager?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

end
