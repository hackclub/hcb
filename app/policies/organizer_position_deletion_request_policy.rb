# frozen_string_literal: true

class OrganizerPositionDeletionRequestPolicy < ApplicationPolicy
  def index?
    user.auditor?
  end

  def new?
    create?
  end

  def create?
    return false unless OrganizerPosition.role_at_least?(user, record.event, :member)

    target_is_in_event = record.event.organizer_positions.include?(record.organizer_position)
    target_has_no_pending_request = record.organizer_position.organizer_position_deletion_requests.under_review.none?

    user.admin? || (target_is_in_event && target_has_no_pending_request && current_user_is_manager? || current_user_is_the_user?)
  end

  def show?
    user.auditor?
  end

  def close?
    user.admin?
  end

  def open?
    user.admin?
  end

  private

  def user_in_event?
    record.event.users.include? user
  end

  def current_user_is_manager?
    OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  def current_user_is_the_user?
    record.organizer_position.user == user
  end

end
