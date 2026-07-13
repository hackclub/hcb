# frozen_string_literal: true

module Payroll
  class PositionPolicy < ApplicationPolicy
    def show?
      # Viewing a single contractor exposes rate, invoices, and payment history.
      event_policy.contractor_details?
    end

    def new?
      event_policy.new_contractor?
    end

    def create?
      event_policy.create_contractor?
    end

    # Reviewing (approving/rejecting) invoices requires the same access as
    # creating a contractor payment — i.e. an admin or manager.
    def review?
      event_policy.create_contractor?
    end

    private

    # `record` may be either a Payroll::Position (e.g. #show authorizes the
    # position it loaded) or an Event (e.g. #new/#create authorize the event
    # before a position exists).
    def event_policy
      event = record.is_a?(Payroll::Position) ? record.event : record
      EventPolicy.new(user, event)
    end

  end
end
