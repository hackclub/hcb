# frozen_string_literal: true

module TransactionEngine
  module SyntaxSugarService
    class LinkedObject
      include ::TransactionEngine::SyntaxSugarService::Shared

      def initialize(canonical_transaction:)
        @canonical_transaction = canonical_transaction
      end

      def run
        if memo.present?

          return likely_check if outgoing_check?
          return likely_clearing_check if clearing_check?
          return likely_dda_check if dda_check?
          return likely_increase_check if increase_check?
          return likely_check_deposit if check_deposit?
          return likely_column_check_deposit if column_check_deposit?

          return likely_ach if outgoing_ach?
          return likely_increase_ach if increase_ach?
          return likely_column_ach if column_ach?

          return likely_column_wire if column_wire?

          return likely_invoice if incoming_invoice?

          return likely_invoice_or_donation_for_fee_refund if fee_refund?

          return likely_donation if donation?

          return likely_disbursement if disbursement?

          return likely_bank_fee if outgoing_bank_fee?

          return reimbursement_expense_payout if reimbursement_expense_payout

          return reimbursement_payout_holding if reimbursement_payout_holding

          return paypal_transfer if paypal_transfer

          return wire if wire

          nil
        end
      end

      private

      def likely_bank_fee
        return nil unless event

        event.bank_fees.where(amount_cents: @canonical_transaction.amount_cents).first
      end

      def likely_check
        return nil unless event

        event.checks.where(check_number: likely_outgoing_check_number).first
      end

      def likely_clearing_check
        return nil unless event

        event.checks.where(check_number: likely_clearing_check_number).first
      end

      def likely_dda_check
        return nil unless event

        event.canonical_transactions.likely_checks.where(amount_cents: -@canonical_transaction.amount_cents, date: @canonical_transaction.date).first.try(:check)
      end

      def likely_increase_check
        if @canonical_transaction.transaction_source_type == "RawColumnTransaction"
          IncreaseCheck.find_by(column_id: @canonical_transaction.column_transaction_id)
        elsif @canonical_transaction.transaction_source_type == "RawIncreaseTransaction"
          increase_check_transfer_id = @canonical_transaction.raw_increase_transaction.increase_transaction.dig("source", "check_transfer_intention", "transfer_id")

          if increase_check_transfer_id
            IncreaseCheck.find_by(increase_id: increase_check_transfer_id)
          else
            IncreaseCheck.find_by("increase_object->'deposit'->>'transaction_id' = ?", @canonical_transaction.raw_increase_transaction.increase_transaction_id)
          end
        end
      end

      def likely_check_deposit
        increase_check_deposit_id = @canonical_transaction.raw_increase_transaction.increase_transaction.dig("source", "check_deposit_acceptance", "check_deposit_id")

        CheckDeposit.find_by(increase_id: increase_check_deposit_id)
      end

      def likely_column_check_deposit
        CheckDeposit.find_by(column_id: @canonical_transaction.column_transaction_id)
      end

      def likely_ach
        return nil unless event

        confirmation_number = @canonical_transaction.likely_ach_confirmation_number
        return nil unless confirmation_number

        event.ach_transfers.find_by(confirmation_number:)
      end

      def likely_increase_ach
        increase_ach_transfer_id = @canonical_transaction.raw_increase_transaction.increase_transaction.dig("source", "ach_transfer_intention", "transfer_id")

        ach_transfer = AchTransfer.find_by(increase_id: increase_ach_transfer_id)
        return unless ach_transfer

        return ach_transfer
      end

      def likely_column_ach
        column_ach_transfer_id = @canonical_transaction.raw_column_transaction&.column_transaction&.dig("transaction_id")
        return AchTransfer.find_by(column_id: column_ach_transfer_id)
      end

      def likely_column_wire
        column_wire_id = @canonical_transaction.raw_column_transaction&.column_transaction&.dig("transaction_id")
        return Wire.find_by(column_id: column_wire_id)
      end

      def likely_invoice
        return nil unless event

        potential_payouts = event.payouts.where("invoice_payouts.statement_descriptor ilike ? and invoice_payouts.amount = ?", "PAYOUT #{ActiveRecord::Base.sanitize_sql_like(likely_incoming_invoice_short_name)}%", amount_cents)

        return nil unless potential_payouts.present?

        potential_payouts.first.invoice # TODO: add smarts where multiple potential payouts to same person with same value
      end

      def likely_invoice_or_donation_for_fee_refund
        return nil unless event

        fee_reimbursement = FeeReimbursement.where("transaction_memo ilike ?", "%#{ActiveRecord::Base.sanitize_sql_like(likely_donation_for_fee_refund_hex_random_id)}%").first

        return nil unless fee_reimbursement

        fee_reimbursement.try(:invoice) || fee_reimbursement.try(:donation)
      end

      def likely_donation
        return nil unless event

        potential_donation_payouts = event.donation_payouts.where("donation_payouts.statement_descriptor ilike ? and donation_payouts.amount = ?", "DONATE #{ActiveRecord::Base.sanitize_sql_like(likely_donation_short_name)}%", amount_cents)

        return nil unless potential_donation_payouts.present?

        potential_donation_payouts.first.donation
      end

      def likely_disbursement
        return nil unless event

        Disbursement.where(id: likely_disbursement_id).first
      end

      def reimbursement_expense_payout
        return nil unless @canonical_transaction.transaction_source_type == "Reimbursement::ExpensePayout"

        Reimbursement::ExpensePayout.find(@canonical_transaction.transaction_source_id)
      end

      def reimbursement_payout_holding
        return nil unless @canonical_transaction.transaction_source_type == "Reimbursement::PayoutHolding"

        Reimbursement::PayoutHolding.find(@canonical_transaction.transaction_source_id)
      end

      def paypal_transfer
        @canonical_transaction.transaction_source if @canonical_transaction.transaction_source_type == PaypalTransfer.name
      end

      def wire
        @canonical_transaction.transaction_source if @canonical_transaction.transaction_source_type == Wire.name
      end

      def event
        @event ||= @canonical_transaction.event
      end

    end
  end
end
