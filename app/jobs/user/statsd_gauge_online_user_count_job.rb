# frozen_string_literal: true

class User
  class StatsdGaugeOnlineUserCountJob < ApplicationJob
    queue_as :default

    def perform
      StatsD.gauge("User.currently_online_count", User.currently_online.count, sample_rate: 1.0)
    end

  end

end

module Statsd
  GaugeOnlineUserCountJob = User::StatsdGaugeOnlineUserCountJob
end
