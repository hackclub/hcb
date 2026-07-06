# frozen_string_literal: true

module Maintenance
  # Backfills StripeCardCharges for RawStripeTransactions created before the
  # model existed. Run BackfillPendingStripeCardChargesTask first.
  class BackfillSettledStripeCardChargesTask < MaintenanceTasks::Task
    def collection
      RawStripeTransaction.where.missing(:stripe_card_charges)
    end

    def process(raw_stripe_transaction)
      # Rows imported before Dec 2020 predate the stripe_authorization_id
      # column; recover it from the raw Stripe payload so matching works.
      if raw_stripe_transaction.stripe_authorization_id.nil? && raw_stripe_transaction.stripe_transaction["authorization"].present?
        raw_stripe_transaction.update!(stripe_authorization_id: raw_stripe_transaction.stripe_transaction["authorization"])
      end

      raw_stripe_transaction.link_stripe_card_charge!
    end

  end
end
