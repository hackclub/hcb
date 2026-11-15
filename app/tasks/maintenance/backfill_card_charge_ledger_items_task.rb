# frozen_string_literal: true

module Maintenance
  # Links Ledger::Items to their CardCharge as a polymorphic linked
  # object. Run after BackfillPendingCardChargesTask and
  # BackfillSettledCardChargesTask so every card charge exists.
  class BackfillCardChargeLedgerItemsTask < MaintenanceTasks::Task
    class AnomalyError < StandardError; end

    def collection
      CardCharge.where.missing(:ledger_item)
    end

    def process(card_charge)
      ledger_item = card_charge.raw_pending_stripe_transaction&.canonical_pending_transaction&.ledger_item
      ledger_item ||= card_charge.raw_stripe_transactions.filter_map { |rst| rst.canonical_transaction&.ledger_item }.first

      if ledger_item.nil?
        Rails.error.report AnomalyError.new("CardCharge #{card_charge.id} has no CT or CPT with a ledger item")
        return
      end

      if ledger_item.linked_object.present?
        unless ledger_item.linked_object == card_charge
          Rails.error.report AnomalyError.new("Ledger::Item #{ledger_item.id} already has linked object #{ledger_item.linked_object_type}##{ledger_item.linked_object_id}; expected to link CardCharge #{card_charge.id}")
        end
        return
      end

      ledger_item.update!(linked_object: card_charge)
    end

  end
end
