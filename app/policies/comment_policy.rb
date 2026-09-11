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


  # See ApplicationPolicy#visible_attributes. Comments are organizer
  # conversation, never public. `Scope` already filters admin-only comments;
  # this governs the fields of the ones that survive it.
  def visible_attributes
    @visible_attributes ||= begin
      return [] unless event_reader? || !!user&.auditor?

      attrs = %i[content user user_id file]
      attrs << :admin_only if !!user&.auditor?
      attrs
    end
  end

  def policy_event
    record.try(:commentable).try(:event)
  end

end
