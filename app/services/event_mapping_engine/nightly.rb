# frozen_string_literal: true

module EventMappingEngine
  class Nightly
    include ::TransactionEngine::Shared

    def initialize(start_date: nil)
      @start_date = start_date || last_1_month
    end

    def run
      map_increase_account_number_transactions!
      map_column_account_number_transactions!

      map_stripe_transactions!
      map_increase_checks!
      map_check_deposits!
      map_achs!
      map_disbursements!
      map_stripe_top_ups!
      map_outgoing_fee_reimbursements!
      map_interest_payments!
      map_svb_sweep_transactions!

      map_hcb_codes_short!

      true
    end

    private

    def map_increase_account_number_transactions!
      CanonicalTransaction.unmapped.likely_increase_account_number.find_each(batch_size: 100) do |ct|
        increase_account_number = ct.raw_increase_transaction.increase_account_number
        next unless increase_account_number

        CanonicalEventMapping.create!(event: increase_account_number.event, canonical_transaction: ct)
      end
    end

    def map_column_account_number_transactions!
      CanonicalTransaction.unmapped.likely_column_account_number.find_each(batch_size: 100) do |ct|
        column_account_number = Column::AccountNumber.find_by(column_id: ct.raw_column_transaction.column_transaction["account_number_id"])
        next unless column_account_number

        CanonicalEventMapping.create!(event: column_account_number.event, canonical_transaction: ct)
      end
    end

    def map_stripe_transactions!
      ::EventMappingEngine::Map::StripeTransactions.new(start_date: @start_date).run
    end

    def map_check_deposits!
      CanonicalTransaction.unmapped.with_column_transaction_type("check.outgoing_debit").find_each(batch_size: 100) do |ct|
        check_deposit = ct.check_deposit
        next unless check_deposit

        CanonicalEventMapping.create!(event: check_deposit.event, canonical_transaction: ct)
      end
    end

    def map_increase_checks!
      ::EventMappingEngine::Map::IncreaseChecks.new.run
    end

    def map_achs!
      ::EventMappingEngine::Map::Achs.new.run
    end

    def map_disbursements!
      ::EventMappingEngine::Map::Disbursements.new.run
    end

    def map_stripe_top_ups!
      ::EventMappingEngine::Map::StripeTopUps.new.run
    end

    def map_svb_sweep_transactions!
      ::EventMappingEngine::Map::SvbSweepTransactions.new.run
    end

    def map_outgoing_fee_reimbursements!
      if Rails.env.production? # somewhat hacky— the "Hack Club Bank" org only exists in production
        CanonicalTransaction.unmapped.where("amount_cents < 0 AND (memo ILIKE '%Stripe fee reimbursement%' OR memo ILIKE '%FEE REIMBU%' OR memo ILIKE '%STRIPE FEE REIMBU%')").find_each(batch_size: 100) do |ct|
          CanonicalEventMapping.create!(canonical_transaction: ct, event_id: EventMappingEngine::EventIds::HACK_CLUB_BANK)
        end
      end
    end

    def map_interest_payments!
      return unless Rails.env.production?

      CanonicalTransaction.unmapped.increase_interest.find_each(batch_size: 100) do |ct|
        CanonicalEventMapping.create!(canonical_transaction: ct, event_id: EventMappingEngine::EventIds::HACK_FOUNDATION_INTEREST)
      end

      CanonicalTransaction.unmapped.likely_column_interest.find_each(batch_size: 100) do |ct|
        CanonicalEventMapping.create!(canonical_transaction: ct, event_id: EventMappingEngine::EventIds::HACK_FOUNDATION_INTEREST)
      end

      CanonicalTransaction.unmapped.svb_sweep_interest.find_each(batch_size: 100) do |ct|
        CanonicalEventMapping.create!(canonical_transaction: ct, event_id: EventMappingEngine::EventIds::HACK_FOUNDATION_INTEREST)
      end
    end

    def map_hcb_codes_short!
      ::EventMappingEngine::Map::HcbCodes::Short.new.run
    end

  end
end
