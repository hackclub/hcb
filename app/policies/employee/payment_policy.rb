# frozen_string_literal: true

class Employee
  class PaymentPolicy < ApplicationPolicy
    def new?
      employee || admin? || manager
    end

    def create?
      employee || admin? || manager
    end

    def review?
      admin? || manager
    end

    def stub?
      employee || admin? || manager || auditor?
    end

    private

    def manager
      OrganizerPosition.role_at_least?(user, record.employee.event, :manager)
    end

    def employee
      record.employee.user == user
    end

  end

end
