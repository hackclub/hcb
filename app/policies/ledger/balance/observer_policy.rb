# frozen_string_literal: true

class Ledger
  module Balance
    class ObserverPolicy < ApplicationPolicy
      def create?
        user == record.user && LedgerPolicy.new(user, record.ledger).show?
      end

      def destroy?
        user.present? && user == record.user
      end

    end
  end

end
