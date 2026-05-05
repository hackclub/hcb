# frozen_string_literal: true

class User
  class EmailUpdatePolicy < ApplicationPolicy
    def verify?
      admin? || record.user == user
    end

    def authorize_change?
      admin? || record.user == user
    end

  end

end
