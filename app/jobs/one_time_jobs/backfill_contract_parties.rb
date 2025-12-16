# frozen_string_literal: true

module OneTimeJobs
  class BackfillContractParties < ApplicationJob
    def perform
      Contract.sent_with_docuseal.find_each do |contract|
        submitters = contract.docuseal_document["submitters"]
        next if submitters.nil?

        submitters.each do |submitter|
          role = case submitter["role"]
                 when "Contract Signee"
                   "signee"
                 when "Cosigner"
                   "cosigner"
                 when "HCB"
                   "hcb"
                 else
                   nil
                 end
          next unless role.present?

          email = submitter["email"]
          user = User.find_by(email:)

          party = nil
          begin
            party = if user.present?
                      contract.parties.create!(role:, user:, skip_pending_validation: true)
                    else
                      contract.parties.create!(role:, external_email: email, skip_pending_validation: true)
                    end
          rescue => e
            Rails.error.report(e)
          end

          next if party.nil?

          if submitter["status"] == "completed"
            party.update!(aasm_state: "signed", signed_at: submitter["completed_at"])
          end
        end
      end
    end

  end

end
