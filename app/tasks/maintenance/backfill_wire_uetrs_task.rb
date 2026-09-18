# frozen_string_literal: true

module Maintenance
  class BackfillWireUetrsTask < MaintenanceTasks::Task
    MAX_RETRIES = 5
    INITIAL_DELAY = 1.0
    MAX_DELAY = 30.0

    throttle_on(backoff: -> { rate_limit_backoff }) { rate_limited? }

    def collection
      Wire.where(uetr: nil).where.not(column_id: nil)
    end

    def process(wire)
      uetr = wire.column_wire_details["uetr"]
      wire.update!(uetr:) if uetr.present?
      self.class.rate_limit_retries = 0
    rescue Faraday::Error => e
      raise unless e.response_status == 429

      self.class.rate_limit_retries += 1
      raise if self.class.rate_limit_retries > MAX_RETRIES

      delay = [INITIAL_DELAY * (2**(self.class.rate_limit_retries - 1)), MAX_DELAY].min
      self.class.rate_limited_until = Time.current + (delay * rand)
    end

    class << self
      attr_accessor :rate_limited_until
      attr_writer :rate_limit_retries

      def rate_limit_retries
        @rate_limit_retries ||= 0
      end

      def rate_limited?
        rate_limited_until.present? && Time.current < rate_limited_until
      end

      def rate_limit_backoff
        return 0.seconds if rate_limited_until.nil?

        [rate_limited_until - Time.current, 0].max
      end

    end

  end
end
