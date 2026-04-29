# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class Control
      class AllowancePolicy < ApplicationPolicy
        def new?
          create?
        end

        def create?
          admin? ||
            OrganizerPosition.role_at_least?(user, record.event, :manager)
        end

      end

    end
  end

end
