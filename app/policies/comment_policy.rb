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
    user.auditor? || teammember?
  end

  def create?
    return false if record.admin_only && !user.auditor?

    user.auditor? || teammember?
  end

  def edit?
    user.admin? || (teammember? && record.user == user) || (user.auditor? && record.user == user)
  end

  def update?
    user.admin? || (teammember? && record.user == user) || (user.auditor? && record.user == user)
  end

  def react?
    show?
  end

  def show?
    user&.auditor? || (teammember? && !record.admin_only)
  end

  def destroy?
    user.admin? || (teammember? && record.user == user) || (user.auditor? && record.user == user)
  end


  # A member shut out of an organization for not enabling two-factor
  # authentication can't take part in its comments either.
  def teammember?
    return false unless users.include?(user)

    commentable = record.commentable
    events = commentable.respond_to?(:events) ? commentable.events : [commentable.try(:event)].compact
    events.none? { |event| event.two_factor_authentication_overdue_for?(user) }
  end

  def users
    user_list = []

    if record.commentable.respond_to?(:events)
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
