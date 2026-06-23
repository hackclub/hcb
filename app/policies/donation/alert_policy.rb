# frozen_string_literal: true

class Donation
  class AlertPolicy < ApplicationPolicy
    def can_update_event?
      EventPolicy.new(user, record.event).update?
    end

    alias_method :create?, :can_update_event?
    alias_method :update?, :can_update_event?
    alias_method :destroy?, :can_update_event?
    alias_method :show?, :can_update_event?

  end

end
