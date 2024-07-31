# frozen_string_literal: true

class User
  class EmailUpdatePolicy < ApplicationPolicy
    def verify?
      user.admin? || record.user == user
    end

    def authorize_change?
      user.admin? || record.user == user
    end

  end

end
