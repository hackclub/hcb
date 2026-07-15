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

    # Editing the position requires the same permission as creating a
    # contractor, but is locked out once its contract has been fully
    # executed (all parties signed) — the position's terms should always
    # match what was legally signed.
    def edit?
      create? && !contract_fully_signed?
    end

    def update?
      edit?
    end

    # Signing its contract during the invite flow requires the same
    # permission as creating a contractor.
    alias_method :contract?, :create?

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

    def contract_fully_signed?
      record.is_a?(Payroll::Position) && record.contracts.not_voided.where(aasm_state: :signed).exists?
    end

  end
end
