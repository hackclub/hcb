# frozen_string_literal: true

module Maintenance
  # Backfills CardCharges for RawStripeTransactions created before the
  # model existed. Run BackfillPendingCardChargesTask first.
  class BackfillSettledCardChargesTask < MaintenanceTasks::Task
    def collection
      RawStripeTransaction.where.missing(:card_charges)
    end

    def process(raw_stripe_transaction)
      raw_stripe_transaction.link_card_charge!
    end

  end
end
