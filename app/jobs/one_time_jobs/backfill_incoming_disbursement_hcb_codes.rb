# frozen_string_literal: true

module OneTimeJobs
  class BackfillIncomingDisbursementHcbCodes < ApplicationJob
    def perform
      Disbursement.find_each do |disbursement|
        HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)
      end
    end

  end
end
