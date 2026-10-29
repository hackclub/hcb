# frozen_string_literal: true

class Ledger
  module Balance
    class ObserverMailerPreview < ActionMailer::Preview
      def low_balance
        observer = Ledger::Balance::Observer.last
        Ledger::Balance::ObserverMailer.with(observer:, balance_cents: observer.amount_cents - 12_34).low_balance
      end

    end
  end

end
