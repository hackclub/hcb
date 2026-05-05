# frozen_string_literal: true

class CommentPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if auditor?
        scope.all
      else
        scope.not_admin_only
      end
    end

  end

  def new?
    auditor? || users.include?(user)
  end

  def create?
    return false if record.admin_only && !auditor?

    auditor? || users.include?(user)
  end

  def edit?
    admin? || (users.include?(user) && record.user == user) || (auditor? && record.user == user)
  end

  def update?
    admin? || (users.include?(user) && record.user == user) || (auditor? && record.user == user)
  end

  def react?
    show?
  end

  def show?
    auditor? || (users.include?(user) && !record.admin_only)
  end

  def destroy?
    admin? || (users.include?(user) && record.user == user) || (auditor? && record.user == user)
  end


  def users
    user_list = []

    if record.commentable.respond_to?(:events)
      user_list = record.commentable.events.collect(&:users).flatten
      user_list = record.commentable.events.collect(&:ancestor_users).flatten
    elsif record.commentable.is_a?(Reimbursement::Report)
      user_list = [record.commentable.user]

      unless record.commentable.event&.users&.empty?
        user_list += record.commentable.event&.users || [] # event&.users can be nil (event-less reports)
        user_list += record.commentable.event&.ancestor_users || []
      end
    elsif record.commentable.is_a?(Event)
      user_list = []
    else
      user_list = record.commentable.event.users
    end

    if record.commentable.respond_to?(:author) && record.commentable.author.present?
      user_list += [record.commentable.author]
    end

    user_list
  end

end
