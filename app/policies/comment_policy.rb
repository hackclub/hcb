# frozen_string_literal: true

class CommentPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.auditor?
        scope.all
      else
        scope.not_admin_only
      end
    end

  end

  def new?
    user.auditor? || has_role?(:reader)
  end

  def create?
    user.auditor? || has_role?(:member)
  end

  def edit?
    has_role?(:member)
  end

  def update?
    has_role?(:member)
  end

  def react?
    update?
  end

  def show?
    user&.auditor? || has_role?(:reader)
  end

  def destroy?
    edit?
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

  def has_role?(role)
    if record.commentable.respond_to?(:events)
      return record.commentable.events.any? do |event|
        OrganizerPosition.role_at_least?(user, event, role)
      end
    end

    event = if record.commentable.is_a?(Reimbursement::Report)
              record.commentable.event
            elsif record.commentable.is_a?(Event)
              record.commentable
            else
              record.commentable.event
            end

    OrganizerPosition.role_at_least?(user, event, role)
  end

end
