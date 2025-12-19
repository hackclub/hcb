# frozen_string_literal: true

module OneTimeJobs
  class BackfillOrganizerContracts < ApplicationJob
    def perform
      Contract.all.find_each do |contract|
        # Contractable at this point will only be OrganizerPositionInvite
        if contract.contractable.is_a?(OrganizerPositionInvite)
          op = contract.contractable.organizer_position
          op&.update!(fiscal_sponsorship_contract: contract)
        end
      end
    end

  end

end
