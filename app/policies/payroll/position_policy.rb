# frozen_string_literal: true

module Payroll
  class PositionPolicy < ApplicationPolicy
    # Viewing a contractor's details (rate, email, invoices, payments) is gated
    # by the event-level sensitive-data check.
    def show?
      event_policy.contractor_details?
    end

    # Inviting a contractor is starting a transfer against an event with the
    # contractors feature enabled.
    def new?
      event_policy.contractors? && event_policy.new_transfer?
    end

    def create?
      event_policy.contractors? && event_policy.create_transfer?
    end

    # Approving/rejecting an invoice requires the same permission as creating a
    # contractor.
    def review?
      create?
    end

    private

    def event_policy
      event = record.is_a?(Payroll::Position) ? record.event : record
      EventPolicy.new(user, event)
    end

  end
end
