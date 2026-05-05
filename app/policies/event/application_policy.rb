# frozen_string_literal: true

class Event
  class ApplicationPolicy < ApplicationPolicy
    def create?
      record.user == user
    end

    def show?
      record.user == user || auditor?
    end

    def airtable?
      auditor?
    end

    def admin_approve?
      admin?
    end

    def admin_reject?
      admin?
    end

    def admin_activate?
      admin?
    end

    def edit?
      admin?
    end

    def update?
      return true if admin?
      return record.user == user if record.draft?

      false
    end

    def archive?
      admin? || record.user == user
    end

    alias_method :unarchive?, :archive?

    def resend_to_cosigner?
      return false if record.contract&.party(:cosigner).nil?

      record.contract.party(:cosigner).pending? && (record.user == user || admin?)
    end

    alias_method :personal_info?, :show?
    alias_method :project_info?, :show?
    alias_method :videos?, :show?
    alias_method :agreement?, :show?
    alias_method :review?, :show?

    def mark_videos_watched?
      admin? || record.user == user
    end

    def submission?
      (record.user == user && !record.draft?) || auditor?
    end

    alias_method :submit?, :update?

  end

end
