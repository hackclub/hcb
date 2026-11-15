# frozen_string_literal: true

module PendingTransactionEngine
  module RawPendingStripeTransactionService
    module Stripe
      class Import
        def initialize(created_after: nil)
          @created_after = created_after
        end

        def run
          authorizations = ::Partners::Stripe::Issuing::Authorizations::List.new(created_after: @created_after).run

          authorizations.each do |authorization|
            ::RawPendingStripeTransaction.find_or_initialize_by(stripe_transaction_id: authorization[:id]).tap do |pt|
              pt.stripe_transaction = authorization
              pt.amount_cents = -authorization[:amount]
              pt.date_posted = Time.at(authorization[:created])
            end.save!
          end

          nil
        end

      end
    end
  end
end
