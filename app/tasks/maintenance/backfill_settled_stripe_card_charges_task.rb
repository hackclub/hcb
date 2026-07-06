# frozen_string_literal: true

module Maintenance
  # Backfills StripeCardCharges for RawStripeTransactions created before the
  # model existed. Run BackfillPendingStripeCardChargesTask first.
  class BackfillSettledStripeCardChargesTask < MaintenanceTasks::Task
    def collection
      RawStripeTransaction.where.missing(:stripe_card_charges)
    end

    def process(raw_stripe_transaction)
      raw_stripe_transaction.link_stripe_card_charge!
    end

  end
end
