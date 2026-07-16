# frozen_string_literal: true

module OneTimeJobs
  class BackfillLedgerEvent < ApplicationJob
    queue_as :metrics

    # Backfills `Ledger::Item`s for all HcbCodes on a single event.
    def perform(event_id)
      event = Event.find(event_id)

      hcb_codes = event.hcb_codes
                       .left_joins(:canonical_transactions, :canonical_pending_transactions)
                       .where("canonical_transactions.id IS NOT NULL OR canonical_pending_transactions.id IS NOT NULL")
                       .distinct
                       .includes(
                         :canonical_transactions,
                         :canonical_pending_transactions,
                         subledger: { card_grant: :ledger },
                         event: :ledger
                       )

      hcb_codes.find_each do |hcb_code|
        safely do
          if hcb_code.subledger_id.present? && (card_grant = hcb_code.subledger&.card_grant)
            ledger = card_grant.ledger
          else
            ledger = hcb_code.event&.ledger
          end
          next unless ledger

          item = Ledger::Item.find_or_create_by!(short_code: hcb_code.short_code) do |li|
            li.amount_cents = hcb_code.amount_cents
            li.memo = "MEMO PLACEHOLDER FROM BACKFILL"
            li.datetime = hcb_code.date || hcb_code.created_at
            li.marked_no_or_lost_receipt_at = hcb_code.marked_no_or_lost_receipt_at
          end

          Ledger::Mapping.find_or_create_by!(ledger:, ledger_item: item) do |mapping|
            mapping.on_primary_ledger = true
          end

          hcb_code.canonical_transactions.update_all(ledger_item_id: item.id)
          hcb_code.canonical_pending_transactions.update_all(ledger_item_id: item.id)

          item.reload
          hcb_code.update!(ledger_item: item)
          item.send(:assign_linked_object!)
          item.custom_memo = item.hcb_code.custom_memo if item.hcb_code&.custom_memo.present?
          item.refresh!
        end
      end
    end

  end
end
