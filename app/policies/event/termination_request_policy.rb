# frozen_string_literal: true

class Event
  class TerminationRequestPolicy < ApplicationPolicy
    def index?
      user&.auditor?
    end

    def show?
      user&.auditor?
    end

    # Only a contract signee can ask HCB to terminate the organization, since
    # they are the ones bound by the fiscal sponsorship agreement. Admins get
    # no shortcut here: terminating is the organization's decision to make.
    def create?
      signee?
    end

    def withdraw?
      record.pending? && signee?
    end

    def close?
      user&.admin?
    end

    def reopen?
      user&.admin?
    end

    private

    def signee?
      return false unless user

      OrganizerPosition.find_by(event: record.event, user:)&.is_signee? || false
    end

  end

end
