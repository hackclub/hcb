# frozen_string_literal: true

module Payroll
  class PositionPolicy < ApplicationPolicy
    def show?
      event_policy.contractor_details?
    end

    def new?
      event_policy.new_contractor?
    end

    def create?
      event_policy.create_contractor?
    end

    def review?
      event_policy.create_contractor?
    end

    private

    def event_policy
      event = record.is_a?(Payroll::Position) ? record.event : record
      EventPolicy.new(user, event)
    end

  end
end
