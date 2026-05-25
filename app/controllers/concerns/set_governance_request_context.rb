# frozen_string_literal: true

module SetGovernanceRequestContext
  extend ActiveSupport::Concern

  included do
    before_action do
      Current.governance_request_context = Governance::RequestContext.from_controller(self)
    end
  end
end
