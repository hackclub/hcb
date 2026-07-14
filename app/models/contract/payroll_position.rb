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
#  reissue_of_id        :bigint
#
# Indexes
#
#  index_contracts_on_contractable   (contractable_type,contractable_id)
#  index_contracts_on_document_id    (document_id)
#  index_contracts_on_reissue_of_id  (reissue_of_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id)
#

class Contract
  class PayrollPosition < Contract
    # TODO: set the real DocuSeal template id for payroll agreements.
    DOCUSEAL_TEMPLATE_ID = 4983902

    after_update_commit :create_document!, if: -> { event.present? && sent_with_docuseal? && aasm_state_previously_changed?(to: "signed") }

    def payload
      organizer = party :organizer
      hcb = party :hcb
      contractor = party :contractor

      base = {
        send_email: false,
        order: "preserved",
        submitters: [
          {
            role: "Organizer",
            email: organizer.email,
            fields: [
              { name: "Project Name", default_value: prefills["title"], readonly: true },
              { name: "Description", default_value: prefills["description"], readonly: true },
              { name: "Start Date", default_value: prefills["start_date"], readonly: true },
              { name: "End Date", default_value: prefills["end_date"], readonly: true },
              { name: "Hourly Rate", default_value: prefills["rate"], readonly: true },
            ]
          },
          {
            role: "HCB",
            email: hcb.email,
            send_email: false,
            fields: [
              {
                name: "Signature",
                default_value: ActionController::Base.helpers.asset_url("zach_signature.png", host: "https://hcb.hackclub.com"),
                readonly: false
              }
            ]
          },
          {
            role: "Contractor",
            email: contractor.email,
            fields: [
              { name: "Name", default_value: prefills["payee_name"] }
            ]
          }
        ]
      }

      # Attach user's uploaded PDF contract onto the template
      if inline_documents?
        base.merge(name: document_name, template_ids: [external_template_id], documents: prefills["documents"])
      else
        base.merge(template_id: external_template_id)
      end
    end

    def agreement_name
      "contractor agreement"
    end

    def required_roles
      ["hcb", "organizer", "contractor"]
    end

    def permitted_roles
      required_roles
    end

    def notifiable_parties
      parties.where(role: :contractor)
    end

    def pending_signee_information
      organizer = party :organizer
      hcb = party :hcb
      contractor = party :contractor

      if organizer && !organizer.signed?
        { label: "Organizer", email: organizer.email }
      elsif hcb && !hcb.signed?
        { label: "HCB point of contact", email: hcb.email }
      elsif contractor && !contractor.signed?
        { label: "You", email: contractor.email }
      else
        nil
      end
    end

    private

    def document_name
      "Contractor agreement with #{prefills["payee_name"]}"
    end

    def document_category
      :contracts
    end

  end

end
