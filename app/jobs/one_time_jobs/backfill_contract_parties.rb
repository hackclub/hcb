# frozen_string_literal: true

module OneTimeJobs
  class BackfillContractParties < ApplicationJob
    def perform
      Contract.sent_with_docuseal.find_each do |contract|
        submitters = nil
        begin
          submitters = contract.docuseal_document["submitters"]
        rescue => e
          Rails.error.report(e)
        end
        next if submitters.nil?

        # Collect all emails from submitters in this contract
        emails = submitters.map { |s| s["email"] }.compact.uniq
        users_by_email = User.where(email: emails).index_by(&:email)

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
          user = users_by_email[email]

          party = nil
          begin
            party = if user.present? && role != "cosigner"
                      contract.parties.create!(role:, user:, skip_pending_validation: true) unless contract.party(role).present?
                    else
                      contract.parties.create!(role:, external_email: email, skip_pending_validation: true) unless contract.party(role).present?
                    end
          rescue => e
            Rails.error.report(e)
          end

          next if party.nil?

          if !party.signed? && submitter["status"] == "completed"
            party.update!(aasm_state: "signed", signed_at: submitter["completed_at"])
          end
        end
      end
    end

  end

end
