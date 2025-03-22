# frozen_string_literal: true

class CommentPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.not_admin_only
      end
    end

  end

  def new?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def create?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def edit?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def update?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def react?
    show?
  end

  def show?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def destroy?
    OrganizerPosition.role_at_least?(user, :member)
  end

  private

  def users
    if record.commentable.respond_to?(:events)
      record.commentable.events.collect(&:users).flatten
    elsif record.commentable.is_a?(Reimbursement::Report)
      [record.commentable.user] + record.commentable.event.users
    elsif record.commentable.is_a?(Event)
      record.commentable.users
    else
      record.commentable.event.users
    end
  end

end
