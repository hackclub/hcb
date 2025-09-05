# frozen_string_literal: true

module Reimbursement
  class ReportPolicy < ApplicationPolicy
    def new?
      admin || team_member
    end

    def create?
      !record.event.demo_mode && (record.event.public_reimbursement_page_available? || admin || OrganizerPosition.role_at_least?(user, record.event, :member))
    end

    def show?
      admin || team_member || creator || auditor
    end

    def wise_transfer_quote?
      admin || team_member || creator || auditor
    end

    def edit?
      admin || manager || (creator && unlocked)
    end

    def update?
      admin || manager || (creator && open)
    end

    def submit?
      unlocked && (admin || manager || creator)
    end

    def draft?
      ((admin || manager || creator) && open) || ((admin || manager) && record.rejected?)
    end

    def request_reimbursement?
      (admin || (manager && !creator)) && open
    end

    def request_changes?
      (admin || manager) && open
    end

    def approve_all_expenses?
      (admin || (manager && !creator)) && open
    end

    def reject?
      (admin || manager) && open
    end

    def update_currency?
      (admin || creator) && open && record.mismatched_currency?
    end

    def admin_approve?
      admin && open
    end

    def admin_send_wise_transfer?
      admin
    end

    def reverse?
      admin
    end

    def destroy?
      ((manager || creator) && record.draft?) || (admin && !record.reimbursed?)
    end

    private

    def admin
      user&.admin?
    end

    def auditor
      user&.auditor?
    end

    def manager
      record.event && OrganizerPosition.find_by(user:, event: record.event)&.manager?
    end

    def team_member
      record.event&.users&.include?(user)
    end

    def creator
      record.user == user
    end

    def open
      !record.closed?
    end

    def unlocked
      !record.locked?
    end

  end
end
