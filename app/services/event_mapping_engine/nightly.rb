# frozen_string_literal: true

module EventMappingEngine
  class Nightly
    include ::TransactionEngine::Shared

    def initialize(start_date: nil)
      @start_date = start_date || last_1_month
    end

    def run
      map_column_account_number_transactions!

      map_stripe_transactions!
      map_check_deposits!
      map_stripe_top_ups!
      map_interest_payments!
      map_svb_sweep_transactions!

      map_hcb_codes_short!

      true
    end

    private

    def map_column_account_number_transactions! # done
      CanonicalTransaction.unmapped.likely_column_account_number.find_each(batch_size: 100) do |ct|
        column_account_number = Column::AccountNumber.find_by(column_id: ct.raw_column_transaction.column_transaction["account_number_id"])
        next unless column_account_number

        CanonicalEventMapping.create!(event: column_account_number.event, canonical_transaction: ct)
      end
    end

    def map_stripe_transactions! # done
      ::EventMappingEngine::Map::StripeTransactions.new(start_date: @start_date).run
    end

    def map_check_deposits! # done
      CanonicalTransaction.unmapped.with_column_transaction_type("check.outgoing_debit").find_each(batch_size: 100) do |ct|
        check_deposit = ct.check_deposit
        next unless check_deposit

        CanonicalEventMapping.create!(event: check_deposit.event, canonical_transaction: ct)
      end
    end

    def map_stripe_top_ups! # fall through
      ::EventMappingEngine::Map::StripeTopUps.new.run
    end

    def map_svb_sweep_transactions! # fall through
      ::EventMappingEngine::Map::SvbSweepTransactions.new.run
    end

    def map_interest_payments! # fall through
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
