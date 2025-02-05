# frozen_string_literal: true

module DonationService
  class Nightly
    def run
      Donation.in_transit.find_each(batch_size: 100) do |donation|
        cpt = donation.canonical_pending_transaction

        next unless cpt
        next unless cpt.settled?
        next unless donation.local_hcb_code.ct.present?

        raise ArgumentError, "anomaly detected when attempting to mark deposited donation #{donation.id}" if anomaly_detected?(donation:)

        begin
          donation.mark_deposited!
        rescue => e
          Airbrake.notify(e)
        end
      end
    end

    private

    def anomaly_detected?(donation:)
      ::PendingEventMappingEngine::AnomalyDetection::BadSettledMapping.new(canonical_pending_transaction: donation.canonical_pending_transaction).run
    end

  end
end
