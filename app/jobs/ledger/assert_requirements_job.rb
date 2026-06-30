# frozen_string_literal: true

class Ledger
  class AssertRequirementsJob < ApplicationJob
    queue_as :low

    class FailedAssertionError < StandardError; end

    class FailedJobError < StandardError; end

    def perform(event_id: nil)
      @event = event_id.present? ? Event.find(event_id) : nil
      @ledger_items = @event&.ledger&.items || Ledger::Item.all
      @cts = @event&.canonical_transactions || CanonicalTransaction.all
      @cpts = @event&.canonical_pending_transactions || CanonicalPendingTransaction.all
      @anomalies = []

      cts_synced_with_hcb_code
      cpts_synced_with_hcb_code
      event_synced_with_hcb_code
      orphaned_cts
      orphaned_cpts

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

    def event_synced_with_hcb_code
      @ledger_items.find_each do |item|
        safely do
          hcb_code = item.hcb_code
          if hcb_code.event.ledger != item.primary_ledger
            report_anomaly "Ledger::Item #{item.hashid} ledger does not match HcbCode #{hcb_code.hashid} event ledger"
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

    def report_anomaly(message)
      @anomalies << message
      Rails.error.report(FailedAssertionError.new(message))
    end

  end
end
