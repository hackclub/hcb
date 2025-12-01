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
    def payload
      {
        template_id: external_template_id,
        send_email: false,
        order: "preserved",
        submitters: [
          {
            role: "Contract Signee",
            email: user.email,
            fields: [
              {
                name: "Contact Name",
                default_value: user.full_name,
                readonly: false
              },
              {
                name: "Telephone",
                default_value: user.phone_number,
                readonly: false
              },
              {
                name: "Email",
                default_value: user.email,
                readonly: false
              },
              {
                name: "Organization",
                default_value: prefills["name"],
                readonly: true
              }
            ]
          },
          if cosigner_email.present?
            {
              role: "Cosigner",
              email: cosigner_email
            }
          end,
          {
            role: "HCB",
            email: creator&.email || "hcb@hackclub.com",
            send_email: true,
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
              },
              {
                name: "The Project",
                default_value: prefills["description"],
                readonly: false
              }
            ]
          }
        ].compact
      }
    end

  end

end
