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
    user.auditor? || users.include?(user)
  end

  def create?
    return false if record.admin_only && !user.auditor?

    user.auditor? || users.include?(user)
  end

  def edit?
    user.admin? || (users.include?(user) && record.user == user) || (user.auditor? && record.user == user)
  end

  def update?
    user.admin? || (users.include?(user) && record.user == user) || (user.auditor? && record.user == user)
  end

  def react?
    show?
  end

  def show?
    user&.auditor? || (users.include?(user) && !record.admin_only)
  end

  def destroy?
    user.admin? || (users.include?(user) && record.user == user) || (user.auditor? && record.user == user)
  end

  private

  def users
    user_list = []

    if record.commentable.respond_to?(:events)
      user_list = record.commentable.events.collect(&:users).flatten
    elsif record.commentable.is_a?(Reimbursement::Report)
      user_list = [record.commentable.user]

      unless record.commentable.event&.users&.empty?
        user_list += record.commentable.event&.users || [] # event&.users can be nil (event-less reports)
      end
    elsif record.commentable.is_a?(Event)
      user_list = record.commentable.users
    else
      user_list = record.commentable.event.users
    end

    if record.commentable.respond_to?(:author) && record.commentable.author.present?
      user_list += [record.commentable.author]
    end

    user_list
  end

end
