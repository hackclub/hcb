# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class ApprovalAttempt
        module Reporting
          extend ActiveSupport::Concern

          included do
            after_create_commit :report_denial, if: :denied?

            private

            # Notify Gary & Mel if transfer attempt is denied
            def report_denial
              ApprovalAttemptMailer.with(approval_attempt: self).report_denial.deliver_later
            end
          end
        end

      end
    end
  end
end
