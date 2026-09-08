# frozen_string_literal: true

module Maintenance
  # Backfills CardCharges for RawPendingStripeTransactions created before
  # the model existed. Run this before BackfillSettledCardChargesTask so
  # settled transactions match into their authorization's charge.
  class BackfillPendingCardChargesTask < MaintenanceTasks::Task
    def collection
      RawPendingStripeTransaction.where.missing(:card_charge)
    end

    def process(raw_pending_stripe_transaction)
      raw_pending_stripe_transaction.link_card_charge!
    end

  end
end
