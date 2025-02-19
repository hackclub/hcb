# frozen_string_literal: true

class Employee
  class PaymentPolicy < ApplicationPolicy
    def new?
      employee
    end

    def create?
      employee
    end

    def review?
      admin || manager
    end

    private

    def admin
      user&.admin?
    end

    def manager
      OrganizerPosition.find_by(user:, event: record.employee.event)&.manager?
    end

    def employee
      record.employee.user == user
    end

  end

end
