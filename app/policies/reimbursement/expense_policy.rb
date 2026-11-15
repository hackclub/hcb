# frozen_string_literal: true

module Reimbursement
  class ExpensePolicy < ApplicationPolicy
    def create?
      unlocked? && (admin? || manager? || creator?)
    end

    def edit?
      unlocked? && (admin? || manager? || creator?) && !record.is_fee?
    end

    def update?
      unlocked? && (admin? || manager? || creator?) && !record.is_fee?
    end

    def destroy?
      unlocked? && (admin? || manager? || creator?) && !record.is_fee?
    end

    def approve?
      (admin? || (manager? && !creator?)) && record.report.submitted?
    end

    def unapprove?
      (admin? || (manager? && !creator?)) && record.report.submitted?
    end

    # Guards the same nil == nil comparison as HcbCodePolicy#user_made_purchase?.
    def user_made_expense?
      user.present? && record&.report&.user == user
    end

    # Who may attach receipts to this expense, through ReceiptablePolicy: the
    # report's submitter, who may not be in the organization, or its members.
    def receiptable_upload?
      admin? || user_made_expense? || OrganizerPosition.role_at_least?(user, record.event, :member)
    end

    # Who may delete a receipt attached to this expense, through ReceiptPolicy:
    # the report's submitter, who may not be in the organization, or a manager.
    # Mileage and fee expenses have only ever let any member delete instead.
    def receipt_destroy?
      return OrganizerPosition.role_at_least?(user, record.event, :member) unless record.instance_of?(Reimbursement::Expense)

      user_made_expense? || manager?
    end

    private

    def admin?
      user&.admin?
    end

    def manager?
      record.event && OrganizerPosition.role_at_least?(user, record.event, :manager)
    end


    def creator?
      record.report.user == user
    end

    def unlocked?
      !record.report.locked?
    end

  end
end
