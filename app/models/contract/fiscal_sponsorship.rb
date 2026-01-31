# frozen_string_literal: true

# == Schema Information
#
# Table name: contracts
#
#  id                   :bigint           not null, primary key
#  aasm_state           :string           not null
#  contractable_type    :string
#  cosigner_email       :string
#  deleted_at           :datetime
#  external_service     :integer
#  include_videos       :boolean
#  prefills             :jsonb
#  signed_at            :datetime
#  type                 :string           not null
#  void_at              :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  contractable_id      :bigint
#  document_id          :bigint
#  external_id          :string
#  external_template_id :string
#
# Indexes
#
#  index_contracts_on_contractable  (contractable_type,contractable_id)
#  index_contracts_on_document_id   (document_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id)
#

class Contract
  class FiscalSponsorship < Contract
    after_update_commit if: ->{ sent_with_docuseal? && aasm_state_previously_changed?(to: "signed") } do
      document = Document.new(
        event:,
        name: "Fiscal sponsorship agreement with #{party(:signee).user.full_name}"
      )
      contract_document = docuseal_document["documents"][0]

      response = Faraday.get(contract_document["url"]) do |req|
        req.headers["X-Auth-Token"] = Credentials.fetch(:DOCUSEAL)
      end

      document.file.attach(
        io: StringIO.new(response.body),
        filename: "#{contract_document["name"]}.pdf"
      )

      document.user = party(:hcb).user
      document.save!
      update!(document:)
    end

    def payload
      signee = party :signee
      cosigner = party :cosigner
      hcb = party :hcb

      payload = {
        template_id: external_template_id,
        send_email: false,
        order: "preserved",
        submitters: [
          {
            role: "Contract Signee",
            email: signee.email,
            fields: [
              {
                name: "Contact Name",
                default_value: signee.user.full_name,
                readonly: false
              },
              {
                name: "Telephone",
                default_value: signee.user.phone_number,
                readonly: false
              },
              {
                name: "Email",
                default_value: signee.email,
                readonly: false
              },
              {
                name: "Organization",
                default_value: prefills["name"],
                readonly: true
              },
              {
                name: "The Project",
                default_value: prefills["description"],
                readonly: false
              }
            ]
          },
          if cosigner.present?
            {
              role: "Cosigner",
              email: cosigner.email
            }
          end,
          {
            role: "HCB",
            email: hcb.email,
            send_email: false,
            fields: [
              {
                name: "HCB ID",
                default_value: prefills["public_id"],
                readonly: true
              },
              {
                name: "Signature",
                default_value: ActionController::Base.helpers.asset_url("zach_signature.png", host: "https://hcb.hackclub.com"),
                readonly: false
              }
            ]
          }
        ].compact
      }

      if contractable.is_a?(OrganizerPositionInvite)
        skip_prefills = contractable.event.plan.contract_skip_prefills
        payload[:submitters] = payload[:submitters].map do |submitter|
          skip_prefill_party = skip_prefills.find { |role, list| role == submitter[:role] }&.second
          next submitter if skip_prefill_party.nil?

          submitter[:fields] = submitter[:fields].reject do |field|
            skip_prefill_party.include? field[:name]
          end
          submitter
        end
      end

      payload
    end

    def required_roles
      ["hcb", "signee"]
    end

    def pending_signee_information
      signee = party :signee
      cosigner = party :cosigner
      hcb = party :hcb

      if signee && !signee.signed?
        { label: "You", email: signee.email }
      elsif cosigner && !cosigner.signed?
        { label: "Your parent/legal guardian", email: cosigner.email }
      elsif hcb && !hcb.signed?
        { label: "HCB point of contact", email: hcb.email }
      else
        nil
      end
    end

  end

end
