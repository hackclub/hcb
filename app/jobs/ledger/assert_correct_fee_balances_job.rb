# frozen_string_literal: true

class Ledger
  # An event's ledger-derived fee balances must agree with the v2 balances the
  # rest of the app bills and displays from.
  class AssertCorrectFeeBalancesJob < AssertRequirementJob
    def perform
      @events = Event.all.includes(:ledger)

      @events.find_each do |event|
        safely do
          fronted_fee_balance_v2_cents = event.fronted_fee_balance_v2_cents
          fronted_fee_balance_cents = event.ledger.fronted_fee_balance_cents
          fee_balance_v2_cents = event.fee_balance_v2_cents
          fee_balance_cents = event.ledger.fee_balance_cents

          if fronted_fee_balance_cents != fronted_fee_balance_v2_cents
            report_anomaly "Event #{event.id} (#{event.slug}) fronted_fee_balance_v2_cents #{fronted_fee_balance_v2_cents} does not match ledger fronted_fee_balance_cents #{fronted_fee_balance_cents}"
          end

          if fee_balance_cents != fee_balance_v2_cents
            report_anomaly "Event #{event.id} (#{event.slug}) fee_balance_v2_cents #{fee_balance_v2_cents} does not match ledger fee_balance_cents #{fee_balance_cents}"
          end
        end
      end
    end

  end

end
