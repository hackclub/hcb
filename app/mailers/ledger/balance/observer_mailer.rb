# frozen_string_literal: true

class Ledger
  module Balance
    class ObserverMailer < ApplicationMailer
      def low_balance
        @observer = params[:observer]
        @balance_cents = params[:balance_cents]
        @event = @observer.ledger.event || @observer.ledger.card_grant.event

        mail to: @observer.user.email_address_with_name, subject: "#{@event.name}'s balance has dropped below #{ApplicationController.helpers.render_money @observer.amount_cents}"
      end

    end
  end

end
