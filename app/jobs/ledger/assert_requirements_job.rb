# frozen_string_literal: true

class Ledger
  class AssertRequirementsJob < ApplicationJob
    queue_as :low

    class FailedAssertionError < StandardError; end

    class FailedJobError < StandardError; end

    def perform(event_id: nil)
      @event = event_id.present? ? Event.find(event_id) : nil
      @ledger_items = (@event&.ledger&.items || Ledger::Item.all).includes(:canonical_transactions, :canonical_pending_transactions, hcb_code: [:canonical_transactions, :canonical_pending_transactions, :event, { subledger: [:card_grant] }])
      @cts = (@event&.canonical_transactions || CanonicalTransaction.all).includes(:ledger_item, :canonical_event_mapping)
      @cpts = (@event&.canonical_pending_transactions || CanonicalPendingTransaction.all).includes(:ledger_item, :canonical_pending_event_mapping)
      @anomalies = []

      cts_synced_with_hcb_code
      cpts_synced_with_hcb_code
      ledger_synced_with_hcb_code
      orphaned_cts
      orphaned_cpts
      cems_match_ledger_mapping
      cpems_match_ledger_mapping

      if @anomalies.any?
        Rails.error.report(FailedJobError.new("Ledger::AssertRequirementsJob failed with #{@anomalies.count} anomalies"))
      end

      @anomalies
    end

    def cts_synced_with_hcb_code
      @ledger_items.find_each do |item|
        safely do
          hcb_code = item.hcb_code
          if hcb_code.canonical_transactions.reorder(id: :asc) != item.canonical_transactions.reorder(id: :asc)
            report_anomaly "Ledger::Item #{item.hashid} canonical_transactions do not match HcbCode #{hcb_code.hashid} canonical_transactions"
          end
        end
      end
    end

    def cpts_synced_with_hcb_code
      @ledger_items.find_each do |item|
        safely do
          hcb_code = item.hcb_code
          if hcb_code.canonical_pending_transactions.reorder(id: :asc) != item.canonical_pending_transactions.reorder(id: :asc)
            report_anomaly "Ledger::Item #{item.hashid} canonical_pending_transactions do not match HcbCode #{hcb_code.hashid} canonical_pending_transactions"
          end
        end
      end
    end

    def ledger_synced_with_hcb_code
      @ledger_items.find_each do |item|
        safely do
          hcb_code = item.hcb_code
          if (hcb_code.subledger&.card_grant || hcb_code.event)&.ledger != item.primary_ledger
            report_anomaly "Ledger::Item #{item.hashid} ledger does not match HcbCode #{hcb_code.hashid} ledger"
          end

          if hcb_code.custom_memo.presence != item.custom_memo.presence
            report_anomaly "Ledger::Item #{item.hashid} custom_memo does not match HcbCode #{hcb_code.hashid} custom_memo"
          end
        end
      end
    end

    def orphaned_cts
      @cts.find_each do |ct|
        safely do
          if ct.ledger_item.nil?
            report_anomaly "CanonicalTransaction #{ct.id} is orphaned (no Ledger::Item)"
          end
        end
      end
    end

    def orphaned_cpts
      @cpts.find_each do |cpt|
        safely do
          if cpt.ledger_item.nil?
            report_anomaly "CanonicalPendingTransaction #{cpt.id} is orphaned (no Ledger::Item)"
          end
        end
      end
    end

    def cems_match_ledger_mapping
      @cts.find_each do |ct|
        safely do
          if (cem = ct.canonical_event_mapping) && (cem.subledger&.card_grant || cem.event)&.ledger != ct.ledger_item&.primary_ledger
            report_anomaly "CanonicalTransaction #{ct.id} canonical_event_mapping does not match Ledger::Item"
          end
        end
      end
    end

    def cpems_match_ledger_mapping
      @cpts.find_each do |cpt|
        safely do
          if (cpem = cpt.canonical_pending_event_mapping) && (cpem.subledger&.card_grant || cpem.event)&.ledger != cpt.ledger_item&.primary_ledger
            report_anomaly "CanonicalPendingTransaction #{cpt.id} canonical_pending_event_mapping does not match Ledger::Item"
          end
        end
      end
    end

    def report_anomaly(message)
      @anomalies << message
      Rails.error.report(FailedAssertionError.new(message))
    end

  end

end
