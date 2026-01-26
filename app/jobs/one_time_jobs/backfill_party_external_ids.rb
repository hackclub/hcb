# frozen_string_literal: true

module OneTimeJobs
  class BackfillPartyExternalIds < ApplicationJob
    def perform
      Contract.where(external_service: 0).find_each(order: :desc) do |contract|
        submitters = contract.docuseal_document["submitters"]

        next if submitters.nil?

        contract.parties.each do |party|
          slug = submitters.select { |s| s["role"] == party.docuseal_role }&.[](0)&.[]("slug")

          party.update!(external_id: slug) if slug.present?
        end

      end
    end

  end

end
