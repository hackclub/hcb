# frozen_string_literal: true

module Api
  class EventPolicy < ApplicationPolicy
    def show?
      record.is_public?
    end

    def transactions?
      record.is_public?
    end

    def donations?
      record.is_public?
    end

    def transfers?
      record.is_public?
    end

    def invoices?
      record.is_public?
    end

    def ach_transfers?
      record.is_public?
    end

    def checks?
      record.is_public?
    end

    def card_charges?
      record.is_public?
    end

    def cards?
      record.is_public?
    end

    def wire_transfers?
      record.is_public?
    end

    def wise_transfers?
      record.is_public?
    end

    def check_deposits?
      record.is_public?
    end

    def reimbursed_expenses?
      record.is_public?
    end

    def hcb_fees?
      record.is_public?
    end

    def create_stripe_card?
      admin_or_user? && is_not_demo_mode?
    end

    def admin_or_user?
      admin? || user?
    end

    def admin?
      user&.admin?
    end

    def user?
      OrganizerPosition.role_at_least?(user, record, :reader)
    end

    def is_not_demo_mode?
      !record.demo_mode?
    end

  end
end
