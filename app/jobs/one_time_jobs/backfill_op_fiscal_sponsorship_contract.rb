# frozen_string_literal: true

module OneTimeJobs
  class BackfillOpFiscalSponsorshipContract
    def self.perform
      ops = OrganizerPosition.where(fiscal_sponsorship_contract: nil)

      ops.each do |op|
        op.update!(fiscal_sponsorship_contract: op.organizer_position_invite.contract)
      end
    end

  end
end
