# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_position_contracts
#
#  id                           :bigint           not null, primary key
#  aasm_state                   :string
#  cosigner_email               :string
#  deleted_at                   :datetime
#  external_service             :integer
#  include_videos               :boolean          default(FALSE), not null
#  purpose                      :integer          default("fiscal_sponsorship_agreement")
#  signed_at                    :datetime
#  void_at                      :datetime
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  document_id                  :bigint
#  external_id                  :string
#  organizer_position_invite_id :bigint           not null
#
# Indexes
#
#  idx_on_organizer_position_invite_id_ab1516f568     (organizer_position_invite_id)
#  index_organizer_position_contracts_on_document_id  (document_id)
#

class OrganizerPosition
  class Contract < ApplicationRecord
    include AASM
    acts_as_paranoid
    has_paper_trail

    belongs_to :organizer_position_invite
    belongs_to :document, optional: true

    validate :one_non_void_contract

    # this does not run unless placed before the following callback idk why
    after_create_commit do
      organizer_position_invite.event.set_airtable_status("Documents sent")
    end

    after_create_commit :send_using_docuseal!, unless: :sent_with_manual?

    validates_email_format_of :cosigner_email, allow_nil: true, allow_blank: true
    normalizes :cosigner_email, with: ->(cosigner_email) { cosigner_email.strip.downcase }

    # does not run when placed after the send_using_docuseal callback, aka here
    # In case a contract is created for a position that is not already marked as owner
    after_create_commit do
      organizer_position_invite.update(role: :owner)
      organizer_position_invite.organizer_position&.update(role: :owner)
    end

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
          organizer_position_invite.deliver
          # Unfreeze the event if this is the first signed contract
          event = organizer_position_invite.event
          if event.organizer_position_contracts.signed.count == 1
            event.update!(financially_frozen: false)
          end
        end
      end

      event :mark_voided do
        transitions from: [:pending, :sent], to: :voided
        after do
          archive_on_docuseal!
          organizer_position_invite.update(role: :manager)
          organizer_position_invite.organizer_position&.update(role: :manager)
        end
      end
    end

    enum :external_service, {
      docuseal: 0,
      manual: 999 # used to backfill contracts
    }, prefix: :sent_with

    enum :purpose, {
      fiscal_sponsorship_agreement: 0,
      termination: 1
    }

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
        template_id: organizer_position_invite.event.plan.contract_docuseal_template_id,
        send_email: false,
        order: "preserved",
        submitters: [
          {
            role: "Contract Signee",
            email: organizer_position_invite.user.email,
            fields: [
              {
                name: "Contact Name",
                default_value: organizer_position_invite.user.full_name,
                readonly: false
              },
              {
                name: "Telephone",
                default_value: organizer_position_invite.user.phone_number,
                readonly: false
              },
              {
                name: "Email",
                default_value: organizer_position_invite.user.email,
                readonly: false
              },
              {
                name: "Organization",
                default_value: organizer_position_invite.event.name,
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
                default_value: organizer_position_invite.event.id,
                readonly: true
              },
              {
                name: "Signature",
                default_value: ActionController::Base.helpers.asset_url("zach_signature.png", host: "https://hcb.hackclub.com"),
                readonly: false
              },
              {
                name: "The Project",
                default_value: organizer_position_invite.event.airtable_record&.[]("Tell us about your event"),
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

    def creator
      user_id = versions.first&.whodunnit
      return nil unless user_id

      User.find_by_id(user_id)
    end

    private

    def one_non_void_contract
      if organizer_position_invite.organizer_position_contracts.where.not(aasm_state: :voided).excluding(self).any?
        self.errors.add(:base, "organizer already has a contract!")
      end
    end

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

end
