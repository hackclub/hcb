# frozen_string_literal: true

module Admin
  module TransferApprovable
    extend ActiveSupport::Concern

    included do
      def ensure_admin_may_approve!(transfer, amount_cents:)
        GovernanceService::Admin::Transfer::Approval.new(
          transfer:,
          amount_cents:,
          user: current_user,
        ).ensure_may_approve!
      end

      rescue_from Governance::Admin::Transfer::ApprovalAttempt::DeniedError do |e|
        redirect_back fallback_location: root_path, flash: { error: e.message }
      end
    end
  end
end
