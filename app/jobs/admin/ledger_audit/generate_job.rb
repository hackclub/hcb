# frozen_string_literal: true

module Admin
  class LedgerAudit
    class GenerateJob < ApplicationJob
      queue_as :low

      def perform
        ledger_audit = Admin::LedgerAudit.create(start: 1.week.ago)

        CanonicalPendingTransaction
          .joins(:raw_pending_stripe_transaction)
          .joins("LEFT JOIN hcb_codes ON hcb_codes.hcb_code = canonical_pending_transactions.hcb_code")
          .joins("LEFT JOIN canonical_pending_event_mappings ON canonical_pending_event_mappings.canonical_pending_transaction_id = canonical_pending_transactions.id")
          .joins("LEFT JOIN events ON events.id = canonical_pending_event_mappings.event_id")
          .where("canonical_pending_transactions.amount_cents < ?", 0)
          .includes(:canonical_pending_declined_mapping)
          .where(canonical_pending_declined_mapping: { canonical_pending_transaction_id: nil })
          .where.not(hcb_codes: { hcb_code: nil })
          .where(created_at: 1.week.ago..)
          .order("RANDOM()")
          .limit(100)
          .map do |cpt|
            task = Admin::LedgerAudit::Task.create(hcb_code: HcbCode.find_by(hcb_code: cpt.hcb_code), admin_ledger_audit: ledger_audit)
            task.save!
          end

        ledger_audit
      end

    end

  end

end
