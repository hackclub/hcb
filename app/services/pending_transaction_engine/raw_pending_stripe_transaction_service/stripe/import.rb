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
          return if authorizations.empty?

          RawPendingStripeTransaction.upsert_all(authorizations.map { |authorization|
            {
              stripe_transaction_id: authorization[:id],
              stripe_transaction: authorization,
              amount_cents: -authorization[:amount],
              date_posted: Time.at(authorization[:created]),
            }
          }, unique_by: :stripe_transaction_id)

          # upsert_all skips callbacks, so link charges for newly inserted rows
          RawPendingStripeTransaction.where(stripe_transaction_id: authorizations.map { |a| a[:id] })
                                     .where.missing(:card_charge)
                                     .find_each(&:link_card_charge!)

          nil
        end

      end
    end
  end
end
