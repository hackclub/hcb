# frozen_string_literal: true

module Maintenance
  # Copies each card charge's authorization method (chip, swipe, contactless,
  # online, ...) from its authorization, for charges authorized before
  # CardCharge started recording it. Run it before DetectSubscriptionsTask,
  # which leaves out charges paid in person.
  class BackfillCardChargeAuthorizationMethodsTask < MaintenanceTasks::Task
    def collection
      CardCharge.where(authorization_method: nil).where.not(raw_pending_stripe_transaction_id: nil).in_batches(of: 1000)
    end

    def process(batch)
      batch.update_all(<<~SQL.squish)
        authorization_method = (
          SELECT raw_pending_stripe_transactions.stripe_transaction->>'authorization_method'
          FROM raw_pending_stripe_transactions
          WHERE raw_pending_stripe_transactions.id = card_charges.raw_pending_stripe_transaction_id
        )
      SQL
    end

  end
end
