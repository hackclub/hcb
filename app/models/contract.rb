# frozen_string_literal: true

# == Schema Information
#
# Table name: contracts
#
#  id                    :bigint           not null, primary key
#  aasm_state            :string
#  contractable_type     :string
#  cosigner_email        :string
#  deleted_at            :datetime
#  external_service      :integer
#  include_videos        :boolean
#  signed_at             :datetime
#  void_at               :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  contractable_id       :bigint
#  document_id           :bigint
#  external_id           :string
#  organizer_position_id :bigint
#
# Indexes
#
#  index_contracts_on_contractable           (contractable_type,contractable_id)
#  index_contracts_on_document_id            (document_id)
#  index_contracts_on_organizer_position_id  (organizer_position_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id)
#  fk_rails_...  (organizer_position_id => organizer_positions.id)
#

class Contract < ApplicationRecord
  include AASM
  acts_as_paranoid
  has_paper_trail

  belongs_to :document, optional: true

  validate :one_non_void_contract

  after_create_commit :send_using_docuseal!, unless: :sent_with_manual?

  validates_email_format_of :cosigner_email, allow_nil: true, allow_blank: true
  normalizes :cosigner_email, with: ->(cosigner_email) { cosigner_email.strip.downcase }

  aasm timestamps: true do
    state :pending, initial: true
    state :sent
    state :signed
    state :voided

    event :mark_sent do
      transitions from: :pending, to: :sent
      after do
        ContractMailer.with(contract: self).notify.deliver_later
        ContractMailer.with(contract: self).notify_cosigner.deliver_later if cosigner_email.present?
      end
    end

    event :mark_signed do
      transitions from: [:pending, :sent], to: :signed
      after do
        contractable.on_contract_signed
      end
    end

    event :mark_voided do
      transitions from: [:pending, :sent], to: :voided
      after do
        archive_on_docuseal!
        contractable.on_contract_voided
      end
    end
  end

  enum :external_service, {
    docuseal: 0,
    manual: 999 # used to backfill contracts
  }, prefix: :sent_with

  def docuseal_document
    docuseal_client.get("submissions/#{external_id}").body
  end

  def user_signature_url
    docuseal_user_signature_url if sent_with_docuseal?
  end

  def docuseal_user_signature_url
    "https://docuseal.co/s/#{docuseal_document["submitters"].select { |s| s["role"] == "Contract Signee" }[0]["slug"]}"
  end

  def cosigner_signature_url
    docuseal_cosigner_signature_url if sent_with_docuseal?
  end

  def docuseal_cosigner_signature_url
    return nil unless cosigner_email.presence

    "https://docuseal.co/s/#{docuseal_document["submitters"].select { |s| s["role"] == "Cosigner" }[0]["slug"]}"
  end

  def pending_signee_information
    return docuseal_pending_signee_information if sent_with_docuseal?

    nil
  end

  def send_using_docuseal!
    raise ArgumentError, "can only send contracts when pending" unless pending?

    payload = {
      template_id: contractable.contract_docuseal_template_id,
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
              default_value: event.name,
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
              default_value: event.id,
              readonly: true
            },
            {
              name: "Signature",
              default_value: ActionController::Base.helpers.asset_url("zach_signature.png", host: "https://hcb.hackclub.com"),
              readonly: false
            },
            {
              name: "The Project",
              default_value: event.airtable_record&.[]("Tell us about your event"),
              readonly: false
            }
          ]
        }
      ].compact
    }

    response = docuseal_client.post("/submissions") do |req|
      req.body = payload.to_json
    end
    update(external_service: :docuseal, external_id: response.body.first["submission_id"])
    mark_sent!
  end

  def archive_on_docuseal!
    docuseal_client.delete("/submissions/#{external_id}")
  end

  def one_non_void_contract
    if contractable.contracts.where.not(aasm_state: :voided).excluding(self).any?
      self.errors.add(:base, "source already has a contract!")
    end
  end

  def creator
    user_id = versions.first&.whodunnit
    return nil unless user_id

    User.find_by_id(user_id)
  end

  def user
    contractable.contract_user
  end

  def event
    contractable.contract_event
  end

  private

  def docuseal_client
    @docuseal_client || begin
      Faraday.new(url: "https://api.docuseal.co/") do |faraday|
        faraday.response :json
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
        faraday.headers["X-Auth-Token"] = Credentials.fetch(:DOCUSEAL)
        faraday.headers["Content-Type"] = "application/json"
      end
    end
  end

  def docuseal_pending_signee_information
    return nil unless sent_with_docuseal?

    submitters = docuseal_document["submitters"]
    signee = submitters.find { |s| s["role"] == "Contract Signee" }
    cosigner = submitters.find { |s| s["role"] == "Cosigner" }
    hcb_signer = submitters.find { |s| s["role"] == "HCB" }

    if signee && signee["status"] != "completed"
      { role: "Contract Signee", label: "You", email: signee["email"] }
    elsif cosigner && cosigner["status"] != "completed"
      { role: "Cosigner", label: "Your parent/legal guardian", email: cosigner["email"] }
    elsif hcb_signer && hcb_signer["status"] != "completed"
      { role: "HCB", label: "HCB point of contact", email: hcb_signer["email"] }
    else
      nil
    end
  end

end
