# frozen_string_literal: true

module OneTimeJobs
  class DetectBalanceAnomalies
    def self.perform
      anomalous_events = []
      Event.find_each do |event|
        anomalous_events << event.id if event.ledger.balance_cents != event.balance_v2_cents
      end

      AdminMailer.balance_anomalies(anomalous_events: Event.where(id: anomalous_events)).deliver_now
    end

  end
end
