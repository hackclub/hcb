# frozen_string_literal: true

module CardLocking
  # Decides trust from pre-aggregated counts. Pure; the query lives in User.
  #
  # Trusted when the on-time rate is at least TRUST_ON_TIME_RATE AND the most
  # recent charge to reach a determined outcome was on time. No minimum count,
  # but zero considered charges is untrusted (no evidence).
  class TrustAssessment
    def initialize(on_time_count:, considered_count:, most_recent_on_time:)
      @on_time_count = on_time_count
      @considered_count = considered_count
      @most_recent_on_time = most_recent_on_time
    end

    def trusted?
      return false if @considered_count.zero?
      return false unless @most_recent_on_time

      (@on_time_count.to_f / @considered_count) >= TRUST_ON_TIME_RATE
    end

  end
end
