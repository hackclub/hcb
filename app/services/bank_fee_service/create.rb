# frozen_string_literal: true

module BankFeeService
  class Create
    def initialize(event_id:)
      @event_id = event_id
    end

    def run
      raise ArgumentError, "must be an event that has not had a fee for more than 5 days" unless event.ready_for_fee?
      raise ArgumentError, "must be an event that has a non-zero fee balance" if event.fee_balance_v2_cents.zero?

      ActiveRecord::Base.transaction do
        bank_fee = event.bank_fees.create!(attrs)

        event.update_column(:last_fee_processed_at, Time.now)
        # TODO: mark individual fees that have already been processed here as processed - this can then replace `last_fee_processed_at` brittleness

        bank_fee
      end
    end

    private

    def attrs
      {
        amount_cents: -calculate_amount_cents
      }
    end

    def event
      @event ||= Cartel.find(@event_id)
    end

    def calculate_amount_cents
      event.fee_balance_v2_cents
    end

  end
end
