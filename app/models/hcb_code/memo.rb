# frozen_string_literal: true

class HcbCode
  module Memo
    extend ActiveSupport::Concern

    included do
      def memo(event: nil)
        return custom_memo if custom_memo.present?

        return card_grant_memo if card_grant?
        return disbursement_memo(event:) if disbursement?
        return invoice_memo if invoice?
        return donation_memo if donation?
        return partner_donation_memo if partner_donation?
        return bank_fee_memo if bank_fee?
        return ach_transfer_memo if ach_transfer?
        return check_memo if check?
        return increase_check_memo if increase_check?
        return check_deposit_memo if check_deposit?
        return fee_revenue_memo if fee_revenue?
        return ach_payment_memo if ach_payment?
        return grant_memo if grant?
        return outgoing_fee_reimbursement_memo if outgoing_fee_reimbursement?
        return reimbursement_payout_holding_memo if reimbursement_payout_holding?
        return reimbursement_expense_payout_memo if reimbursement_expense_payout?
        return reimbursement_payout_transfer_memo if reimbursement_payout_transfer?

        ct.try(:smart_memo) || pt.try(:smart_memo) || ""
      end

      def custom_memo
        ct.try(:custom_memo) || pt.try(:custom_memo)
      end

      def card_grant_memo
        "Grant to #{disbursement.card_grant.user.name}"
      end

      def disbursement_memo(event: nil)
        return disbursement.special_appearance_memo if disbursement.special_appearance_memo

        if event == disbursement.source_event
          "Transfer to #{disbursement.destination_event.name}".strip.upcase
        elsif event == disbursement.destination_event
          "Transfer from #{disbursement.source_event.name}".strip.upcase
        else
          "Transfer from #{disbursement.source_event.name} to #{disbursement.destination_event.name}".strip.upcase
        end

      end

      def invoice_memo
        "INVOICE TO #{invoice.smart_memo}"
      end

      def donation_memo
        "DONATION FROM #{donation.smart_memo}#{donation.refunded? ? " (REFUNDED)" : ""}"
      end

      def partner_donation_memo
        "DONATION FROM #{partner_donation.smart_memo}#{partner_donation.refunded? ? " (REFUNDED)" : ""}"
      end

      def bank_fee_memo
        bank_fee.amount_cents.negative? ? "FISCAL SPONSORSHIP" : "FISCAL SPONSORSHIP FEE CREDIT"
      end

      def ach_transfer_memo
        "ACH TO #{ach_transfer.smart_memo}"
      end

      def check_memo
        "CHECK TO #{check.smart_memo}"
      end

      def increase_check_memo
        "Check to #{increase_check.recipient_name}".upcase
      end

      def check_deposit_memo
        "CHECK DEPOSIT"
      end

      def fee_revenue_memo
        "Fee revenue from #{fee_revenue.start.strftime("%b %e")} to #{fee_revenue.end.strftime("%b %e")}"
      end

      def ach_payment_memo
        "Bank transfer"
      end

      def grant_memo
        "Grant to #{canonical_pending_transactions.first.grant.recipient_organization}"
      end

      def outgoing_fee_reimbursement_memo
        "🗂️ Stripe fee reimbursements for week of #{ct.date.beginning_of_week.strftime("%-m/%-d")}"
      end

      def reimbursement_payout_holding_memo
        "Payout Holding for Reimbursement Report #{reimbursement_payout_holding.report.id}"
      end

      def reimbursement_expense_payout_memo
        reimbursement_expense_payout.expense.memo
      end

      def reimbursement_payout_transfer_memo
        return "Payout Transfer for Reimbursement Report #{increase_check.reimbursement_payout_holding.report.id}" if increase_check?

        return "Payout Transfer for Reimbursement Report #{ach_transfer.reimbursement_payout_holding.report.id}" if ach_transfer?

        "Payout Transfer for Unknown Reimbursement Report"
      end

    end
  end

end
