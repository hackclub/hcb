# frozen_string_literal: true

module PendingEventMappingEngine
  class Nightly
    def run
      map_canonical_pending_outgoing_check!
      settle_canonical_pending_outgoing_check!
      decline_canonical_pending_outgoing_check!

      settle_canonical_pending_increase_check!

      settle_canonical_pending_check_deposit!
      decline_canonical_pending_check_deposit!

      map_canonical_pending_outgoing_ach!
      settle_canonical_pending_outgoing_ach!
      decline_canonical_pending_outgoing_ach!

      map_canonical_pending_stripe!
      settle_canonical_pending_stripe!
      decline_canonical_pending_stripe!

      map_canonical_pending_donation!
      settle_canonical_pending_donation!
      settle_canonical_pending_donation_hcb_code!
      decline_canonical_pending_donation!

      map_canonical_pending_invoice!
      settle_canonical_pending_invoice!
      settle_canonical_pending_invoice_hcb_code!
      decline_canonical_pending_invoice!

      map_canonical_pending_bank_fee!
      settle_canonical_pending_bank_fee_hcb_code!

      map_canonical_pending_outgoing_disbursement!
      settle_canonical_pending_outgoing_disbursement_hcb_code!
      decline_canonical_pending_outgoing_disbursement!

      map_canonical_pending_incoming_disbursement!
      settle_canonical_pending_incoming_disbursement_hcb_code!
      decline_canonical_pending_incoming_disbursement!

      settle_canonical_pending_expense_payout!

      true
    end

    private

    def map_canonical_pending_incoming_disbursement!
      ::PendingEventMappingEngine::Map::IncomingDisbursement.new.run
    end

    def settle_canonical_pending_incoming_disbursement_hcb_code!
      ::PendingEventMappingEngine::Settle::IncomingDisbursementHcbCode.new.run
    end

    def decline_canonical_pending_incoming_disbursement!
      ::PendingEventMappingEngine::Decline::IncomingDisbursement.new.run
    end

    def map_canonical_pending_outgoing_disbursement!
      ::PendingEventMappingEngine::Map::OutgoingDisbursement.new.run
    end

    def settle_canonical_pending_outgoing_disbursement_hcb_code!
      ::PendingEventMappingEngine::Settle::OutgoingDisbursementHcbCode.new.run
    end

    def decline_canonical_pending_outgoing_disbursement!
      ::PendingEventMappingEngine::Decline::OutgoingDisbursement.new.run
    end

    def map_canonical_pending_outgoing_check!
      ::PendingEventMappingEngine::Map::OutgoingCheck.new.run
    end

    def settle_canonical_pending_outgoing_check!
      ::PendingEventMappingEngine::Settle::OutgoingCheck.new.run
    end

    def decline_canonical_pending_outgoing_check!
      ::PendingEventMappingEngine::Decline::OutgoingCheck.new.run
    end

    def settle_canonical_pending_increase_check!
      CanonicalPendingTransaction.unsettled.increase_check.find_each(batch_size: 100) do |cpt|
        if cpt.local_hcb_code.ct
          CanonicalPendingSettledMapping.create!(canonical_pending_transaction: cpt, canonical_transaction: cpt.local_hcb_code.ct)
        end
      end
    end

    def settle_canonical_pending_check_deposit!
      CanonicalPendingTransaction.unsettled.check_deposit.find_each(batch_size: 100) do |cpt|
        if cpt.local_hcb_code.ct
          CanonicalPendingSettledMapping.create!(canonical_pending_transaction: cpt, canonical_transaction: cpt.local_hcb_code.ct)
        end
      end
    end

    def decline_canonical_pending_check_deposit!
      CanonicalPendingTransaction.check_deposit
                                 .not_declined
                                 .includes(:check_deposit)
                                 .where(check_deposit: { increase_status: :rejected })
                                 .find_each(batch_size: 100) { |cpt| cpt.decline! }
    end

    def map_canonical_pending_outgoing_ach!
      ::PendingEventMappingEngine::Map::OutgoingAch.new.run
    end

    def settle_canonical_pending_outgoing_ach!
      ::PendingEventMappingEngine::Settle::OutgoingAch.new.run
    end

    def decline_canonical_pending_outgoing_ach!
      ::PendingEventMappingEngine::Decline::OutgoingAch.new.run
    end

    def map_canonical_pending_stripe!
      ::PendingEventMappingEngine::Map::Stripe.new.run
    end

    def settle_canonical_pending_stripe!
      ::PendingEventMappingEngine::Settle::Stripe.new.run
    end

    def decline_canonical_pending_stripe!
      ::PendingEventMappingEngine::Decline::Stripe.new.run
    end

    def map_canonical_pending_donation!
      ::PendingEventMappingEngine::Map::Donation.new.run
    end

    def settle_canonical_pending_donation!
      ::PendingEventMappingEngine::Settle::Donation.new.run
    end

    def settle_canonical_pending_donation_hcb_code!
      ::PendingEventMappingEngine::Settle::DonationHcbCode.new.run
    end

    def decline_canonical_pending_donation!
      # ::PendingEventMappingEngine::Decline::Donation.new.run
    end

    def map_canonical_pending_invoice!
      ::PendingEventMappingEngine::Map::Invoice.new.run
    end

    def settle_canonical_pending_invoice!
      ::PendingEventMappingEngine::Settle::Invoice.new.run
    end

    def settle_canonical_pending_invoice_hcb_code!
      ::PendingEventMappingEngine::Settle::InvoiceHcbCode.new.run
    end

    def decline_canonical_pending_invoice!
      # ::PendingEventMappingEngine::Decline::Invoice.new.run
    end

    def map_canonical_pending_bank_fee!
      ::PendingEventMappingEngine::Map::BankFee.new.run
    end

    def settle_canonical_pending_bank_fee_hcb_code!
      ::PendingEventMappingEngine::Settle::BankFeeHcbCode.new.run
    end

    def settle_canonical_pending_expense_payout!
      CanonicalPendingTransaction.unsettled.reimbursement_expense_payout.find_each(batch_size: 100) do |cpt|
        if (ct = cpt.local_hcb_code.ct)
          CanonicalPendingSettledMapping.create!(canonical_pending_transaction: cpt, canonical_transaction: ct)
        end
      end
    end

  end
end
