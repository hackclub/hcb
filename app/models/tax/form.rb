# frozen_string_literal: true

# == Schema Information
#
# Table name: tax_forms
#
#  id                             :bigint           not null, primary key
#  aasm_state                     :string           not null
#  address_city                   :string
#  address_country                :string
#  address_line1                  :string
#  address_line2                  :string
#  address_postal_code            :string
#  address_state                  :string
#  completed_at                   :datetime
#  deleted_at                     :datetime
#  external_service               :string           not null
#  failed_at                      :datetime
#  form_type                      :string
#  sent_at                        :datetime
#  signing_url                    :string
#  taxbandits_status              :string
#  taxbandits_tin_matching_status :string
#  tin_hash                       :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  external_id                    :string
#  legal_entity_id                :bigint           not null
#
# Indexes
#
#  index_tax_forms_on_legal_entity_id  (legal_entity_id)
#
module Tax
  class Form < ApplicationRecord
    include AASM
    include Hashid::Rails
    include PublicIdentifiable

    set_public_id_prefix :tfm
    acts_as_paranoid
    has_paper_trail

    belongs_to :legal_entity

    enum :form_type, { W8BEN: "W8BEN", W9: "W9", W8BENE: "W8BENE", W8ECI: "W8ECI", W8IMY: "W8IMY", W8EXP: "W8EXP" }
    enum :external_service, { manual: "manual", taxbandits: "taxbandits" }, prefix: :sent_with

    # https://developer.taxbandits.com/docs/whcertificate/status/
    enum :taxbandits_status, %w[
      url_generated
      order_created
      scheduled
      sent
      opened
      completed
      awaiting_tin_certificate
      completed_and_tin_match_inprogress
      invalid
      bounced
      order_not_created
    ].index_with(&:itself), prefix: :taxbandits

    enum :taxbandits_tin_matching_status, %w[
      order_created
      success
      failed
    ].index_with(&:itself), prefix: :taxbandits_tin_match

    scope :not_discarded, -> { where.not(aasm_state: :discarded) }

    after_update if: -> {
      taxbandits_status_previously_changed?(to: :completed) ||
        taxbandits_status_previously_changed?(to: :completed_and_tin_match_inprogress)
    } do
      mark_completed! if may_mark_completed?
    end

    after_update if: -> { tin_hash_previously_changed?(from: nil) } do
      legal_entity.update!(tin_hash:) if legal_entity.tin_hash.nil?
    end

    aasm timestamps: true do
      state :pending, initial: true
      state :sent # Request sent to TaxBandits, not necessarily email sent
      state :completed
      state :failed # Failed to create document / send email
      state :discarded

      event :mark_sent do
        transitions from: :pending, to: :sent
      end

      event :mark_completed do
        transitions from: :sent, to: :completed
        after do
          import_taxbandits_data if sent_with_taxbandits?

          legal_entity.payments.each(&:on_legal_entity_payable) if legal_entity.payable?
        end
      end

      event :mark_failed do
        transitions from: :sent, to: :failed
      end

      event :mark_discarded do
        transitions from: [:pending, :sent, :completed], to: :discarded
      end
    end

    def send!
      raise ArgumentError, "can only send tax forms when pending" unless pending? && external_id.blank?

      case external_service
      when "taxbandits"
        send_using_taxbandits!
      when "manual"
        Rails.logger.info("[Tax::Form] NO-OP: skipping because the external service is 'manual'.")
      else
        raise ArgumentError, "Unable to send tax form using unknown external service (#{external_service})"
      end

      mark_sent!
    end

    def remote_taxbandits_submission
      TaxbanditsService.get_submission(public_id)
    end

    def remote_taxbandits_list_entry
      TaxbanditsService.get_list_entry(public_id)
    end

    def sync_with_taxbandits
      response = TaxbanditsService.get_status(public_id)

      if response.present?
        update!(
          taxbandits_status: response["FormStatus"].downcase,
          taxbandits_tin_matching_status: response["TINMatching"]&.[]("Status")&.downcase
        )
      end
    end

    def inferred_entity_type
      submission = remote_taxbandits_submission
      return if submission.nil?

      case submission["FormType"]
      when "FormW9"
        submission["FormW9"]["FormData"]["TINType"] == "SSN" ? :person : :business
      when "FormW8BEN"
        :person
      when "FormW8BENE"
        :business
      when "FormW8ECI"
        submission["FormW8ECI"]["FormData"]["EntityType"] == "INDIVIDUAL" ? :person : :business
      when "FormW8IMY"
        :business
      when "FormW8EXP"
        :business
      else
        raise ArgumentError, "unknown tax form type"
      end
    end

    def masked_tin
      entry = remote_taxbandits_list_entry
      entry&.[]("TIN")
    end

    private

    def send_using_taxbandits!
      response = TaxbanditsService.create_whcertificate(id: public_id, name: legal_entity.name)

      update!(external_service: :taxbandits, signing_url: response["Url"], external_id: response["SubmissionId"])
      sync_with_taxbandits
    end

    def import_taxbandits_data
      submission = remote_taxbandits_submission
      return if submission.nil?

      submission_form_type = submission["FormType"]
      form_data = submission.dig(TaxbanditsService::TAXBANDITS_FORM_DATA_KEYS[submission_form_type], "FormData")

      return if form_data.blank?

      address = case submission_form_type
                when "FormW9"
                  form_data["Address"]
                when "FormW8BEN", "FormW8ECI"
                  form_data["MailAdd"]
                when "FormW8BENE", "FormW8IMY", "FormW8EXP"
                  form_data.dig("Part1", "MailAdd")
                end

      return if address.blank?

      us_tin, foreign_tin = case submission_form_type
                            when "FormW9"
                              [form_data["TIN"], nil]
                            when "FormW8BEN"
                              [form_data["USTIN"], form_data["ForeignTIN"]]
                            when "FormW8ECI"
                              [form_data["TIN"], form_data["ForeignTIN"]]
                            when "FormW8BENE", "FormW8IMY", "FormW8EXP"
                              [form_data.dig("Part1", "USTIN"), form_data.dig("Part1", "ForeignTIN")]
                            end
      tin = us_tin.presence || foreign_tin.presence
      tin_hash = Tax::IdentificationNumber::Hasher.hash_tin(tin)

      update!(
        form_type: submission_form_type[4..],
        tin_hash:,
        address_line1: address["Address1"],
        address_line2: address["Address2"],
        address_city: address["City"],
        address_state: address["State"] || address["ProvinceOrStateNm"],
        address_postal_code: address["PostalCd"] || address["ZipCd"],
        address_country: address["Country"]
      )
    end

  end
end
