# frozen_string_literal: true

module Maintenance
  # Rebuilds subscriptions one ledger and merchant at a time, from that
  # merchant's charges on the ledger, oldest first (see
  # Ledger::Subscription::Detect.rebuild). Safe to re-run, e.g. after changing the
  # detection rules.
  #
  # Run BackfillCardChargeAuthorizationMethodsTask first, so in-person charges
  # are left out. A charge that settles while its ledger and merchant are being
  # rebuilt waits for the rebuild (see Ledger::Subscription::Detect.lock!).
  # The list of ledgers and merchants is worked out again when the task
  # resumes, so one that appears or disappears meanwhile can shift it by one;
  # running the task again catches it.
  class DetectSubscriptionsTask < MaintenanceTasks::Task
    def collection
      charges = CardCharge.where.not(stripe_card_id: nil).where.not(merchant_network_id: [nil, ""]).card_not_present
      with_charges = Ledger::Item.subscription_eligible
                                 .where(linked_object_id: charges.select(:id))
                                 .joins(:primary_mapping)
                                 .joins("JOIN card_charges ON card_charges.id = ledger_items.linked_object_id")
                                 .group("ledger_mappings.ledger_id", "card_charges.merchant_network_id")
                                 .having("COUNT(*) >= ?", Ledger::Subscription::Detect::MIN_YEARLY_CHARGES)
                                 .pluck("ledger_mappings.ledger_id", "card_charges.merchant_network_id")

      # Subscriptions with no charges left to detect from are rebuilt too, which
      # deletes them.
      (with_charges + Ledger::Subscription.distinct.pluck(:ledger_id, :merchant_key)).uniq.sort
    end

    def process((ledger_id, merchant_key))
      Ledger::Subscription::Detect.rebuild(ledger: Ledger.find(ledger_id), merchant_key:)
    end

  end
end
