# frozen_string_literal: true

class GSuite
  class SetVerificationKeyJob < ApplicationJob
    queue_as :default
    def perform(g_suite_id)
      @g_suite_id = g_suite_id
      key = GSuiteService::GetVerificationKey.new(g_suite_id:).run

      GSuiteService::Update.new(g_suite_id: g_suite.id, domain: g_suite.domain, verification_key: key).run
    end

    def g_suite
      GSuite.find(@g_suite_id)
    end

  end

end

module GSuiteJob
  SetVerificationKey = GSuite::SetVerificationKeyJob
end
