# frozen_string_literal: true

module Reimbursement
  class ExpensePolicy < ApplicationPolicy
    def create?
      draft && (admin || manager || creator)
    end

    def edit?
      draft && (admin || manager || creator) && !record.is_fee?
    end

    def update?
      draft && (admin || manager || creator) && !record.is_fee?
    end

    def destroy?
      draft && (admin || manager || creator) && !record.is_fee?
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
      record.event && OrganizerPosition.role_at_least?(user, record.event, :manager)
    end

    def team_member
      record.event&.users&.include?(user)
    end

    def creator
      record.report.user == user
    end

    def draft
      record.report.draft?
    end

  end
end
