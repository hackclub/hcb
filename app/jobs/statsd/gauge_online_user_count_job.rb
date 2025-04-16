# frozen_string_literal: true

class Statsd
  class GaugeOnlineUserCountJob < ApplicationJob
    queue_as :default

    def perform
      StatsD.gauge("User.currently_online_count", User.currently_online.count, sample_rate: 1.0)
    end

  end
end

module StatsdJob
  GaugeOnlineUserCount = Statsd::GaugeOnlineUserCountJob
end
