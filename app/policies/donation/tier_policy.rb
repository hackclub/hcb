class Donation
  class TierPolicy < ApplicationPolicy
    def can_update_event?
      EventPolicy.new(user, record.event).edit?
    end

    alias_method :set_index?, :can_update_event?
    alias_method :create?, :can_update_event?
    alias_method :update?, :can_update_event?
    alias_method :destroy?, :can_update_event?


  end

end
