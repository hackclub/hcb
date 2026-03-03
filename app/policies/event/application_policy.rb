# frozen_string_literal: true

class Event
  class ApplicationPolicy < ApplicationPolicy
    def create?
      record.user == user
    end

    def show?
      record.user == user || user.auditor?
    end

    def airtable?
      user.auditor?
    end

    def admin_approve?
      user.admin?
    end

    def admin_reject?
      user.admin?
    end

    def admin_activate?
      user.admin?
    end

    def edit?
      user.admin?
    end

    def update?
      return true if user.admin?
      return record.user == user if record.draft?

      false
    end

    def archive?
      user.admin? || record.user == user
    end

    def resend_to_cosigner?
      return false if record.contract&.party(:cosigner).nil?

      record.contract.party(:cosigner).pending? && (record.user == user || user.admin?)
    end

    alias_method :personal_info?, :show?
    alias_method :project_info?, :show?
    alias_method :agreement?, :show?
    alias_method :review?, :show?

    def submission?
      (record.user == user || user.auditor?) && !record.draft?
    end

    alias_method :submit?, :update?

  end

end
