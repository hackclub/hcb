# frozen_string_literal: true

module Maintenance
  # Backfills StripeCardCharges for RawPendingStripeTransactions created before
  # the model existed. Run this before BackfillSettledStripeCardChargesTask so
  # settled transactions match into their authorization's charge.
  class BackfillPendingStripeCardChargesTask < MaintenanceTasks::Task
    def collection
      RawPendingStripeTransaction.where.missing(:stripe_card_charge)
    end

    def process(raw_pending_stripe_transaction)
      raw_pending_stripe_transaction.link_stripe_card_charge!
    end

  end
end
