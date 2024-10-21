# frozen_string_literal: true

module PendingTransactionEngine
  class Nightly
    def run
      # 1 raw imports
      import_raw_pending_outgoing_check_transactions!
      import_raw_pending_outgoing_ach_transactions!
      import_raw_pending_stripe_transactions!
      import_raw_pending_donation_transactions!
      import_raw_pending_invoice_transactions!
      import_raw_pending_bank_fee_transactions!
      import_raw_pending_outgoing_disbursement_transactions!
      import_raw_pending_incoming_disbursement_transactions!

      # 2 canonical
      canonize_raw_pending_outgoing_check_transactions!
      canonize_raw_pending_outgoing_ach_transactions!
      canonize_raw_pending_stripe_transactions!
      canonize_raw_pending_donation_transactions!
      canonize_raw_pending_invoice_transactions!
      canonize_raw_pending_bank_fee_transactions!
      canonize_raw_pending_incoming_disbursement_transactions!
      canonize_raw_pending_outgoing_disbursement_transactions!
    end

    private

    def import_raw_pending_incoming_disbursement_transactions!
      ::PendingTransactionEngine::RawPendingIncomingDisbursementTransactionService::Disbursement::Import.new.run
    end

    def canonize_raw_pending_incoming_disbursement_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::IncomingDisbursement.new.run
    end

    def import_raw_pending_outgoing_disbursement_transactions!
      ::PendingTransactionEngine::RawPendingOutgoingDisbursementTransactionService::Disbursement::Import.new.run
    end

    def canonize_raw_pending_outgoing_disbursement_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::OutgoingDisbursement.new.run
    end

    def import_raw_pending_outgoing_check_transactions!
      ::PendingTransactionEngine::RawPendingOutgoingCheckTransactionService::OutgoingCheck::Import.new.run
    end

    def canonize_raw_pending_outgoing_check_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::OutgoingCheck.new.run
    end

    def import_raw_pending_outgoing_ach_transactions!
      ::PendingTransactionEngine::RawPendingOutgoingAchTransactionService::OutgoingAch::Import.new.run
    end

    def canonize_raw_pending_outgoing_ach_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::OutgoingAch.new.run
    end

    def import_raw_pending_stripe_transactions!
      ::PendingTransactionEngine::RawPendingStripeTransactionService::Stripe::Import.new(
        created_after: 2.weeks.ago.to_i
      ).run
    end

    def canonize_raw_pending_stripe_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::Stripe.new.run
    end

    def import_raw_pending_donation_transactions!
      ::PendingTransactionEngine::RawPendingDonationTransactionService::Donation::Import.new.run
    end

    def canonize_raw_pending_donation_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::Donation.new.run
    end

    def import_raw_pending_invoice_transactions!
      ::PendingTransactionEngine::RawPendingInvoiceTransactionService::Invoice::Import.new.run
    end

    def canonize_raw_pending_invoice_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::Invoice.new.run
    end

    def import_raw_pending_bank_fee_transactions!
      ::PendingTransactionEngine::RawPendingBankFeeTransactionService::BankFee::Import.new.run
    end

    def canonize_raw_pending_bank_fee_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::BankFee.new.run
    end

  end
end
