# frozen_string_literal: true

module Reimbursement
  class ExpensePolicy < ApplicationPolicy
    def create?
      unlocked && (admin || manager || creator)
    end

    def edit?
      unlocked && (admin || manager || creator)
    end

    def update?
      unlocked && (admin || manager || creator)
    end

    def destroy?
      unlocked && (admin || manager || creator)
    end

    def approve?
      (admin || (manager && !creator)) && record.report.submitted?
    end

    def unapprove?
      (admin || (manager && !creator)) && record.report.submitted?
    end

    def user_made_expense?
      record&.report&.user == user
    end

    alias receiptable_upload? user_made_expense?

    private

    def admin
      user&.admin?
    end

    def manager
      record.event && OrganizerPosition.find_by(user:, event: record.event)&.manager?
    end

    def team_member
      record.event&.users&.include?(user)
    end

    def creator
      record.report.user == user
    end

    def unlocked
      !record.report.locked?
    end

  end
end
