# frozen_string_literal: true

module GSuiteService
  class MarkVerifying
    def initialize(g_suite_id:)
      @g_suite_id = g_suite_id
    end

    def run
      ActiveRecord::Base.transaction do
        g_suite.mark_verifying!

        g_suite
      end
    end

    private

    def g_suite
      @g_suite ||= GSuite.find(@g_suite_id)
    end

  end
end
