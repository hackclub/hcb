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
    user.admin? || users.include?(user)
  end

  def create?
    user.admin? || users.include?(user)
  end

  def edit?
    user.admin? || (users.include?(user) && record.user == user)
  end

  def update?
    user.admin? || (users.include?(user) && record.user == user)
  end

  def react?
    show?
  end

  def show?
    user.admin? || (users.include?(user) && !record.admin_only)
  end

  def destroy?
    user.admin? || (users.include?(user) && record.user == user)
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
