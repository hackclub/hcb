# frozen_string_literal: true

module GSuiteService
  class CreateRevocation
    def initialize(g_suite_id:, reason:)
      @g_suite_id = g_suite_id
      @reason = reason
    end

    def run
      case @reason
      when :dns
        @g_suite.revocation = GSuiteRevocation.create!(g_suite: @g_suite, invalid_dns: true)
      when :inactivity
        @g_suite.revocation = GSuiteRevocation.create!(g_suite: @g_suite, no_account_activity: true)
      else
        @g_suite.revocation = GSuiteRevocation.create!(g_suite: @g_suite, other: true, other_reason: "")
      end
    end

    private

    def g_suite
      @g_suite ||= GSuite.find(@g_suite_id)
    end

  end
end
